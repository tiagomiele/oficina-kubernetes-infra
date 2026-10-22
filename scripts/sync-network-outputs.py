#!/usr/bin/env python3

import argparse
import json
import os
import sys
from collections.abc import Mapping, Sequence
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

API_BASE_URL = "https://app.terraform.io/api/v2"
DESCRIPTION = "Gerenciada por scripts/sync-network-outputs.py"


class SyncError(RuntimeError):
    pass


class HcpClient:
    def __init__(self, token: str) -> None:
        if not token.strip():
            raise SyncError("TF_API_TOKEN não configurado.")
        self._token = token

    def _request(
        self, method: str, path: str, payload: Mapping[str, object] | None = None
    ) -> Mapping[str, object]:
        body = None if payload is None else json.dumps(payload).encode("utf-8")
        request = Request(
            f"{API_BASE_URL}/{path}",
            data=body,
            method=method,
            headers={
                "Authorization": f"Bearer {self._token}",
                "Content-Type": "application/vnd.api+json",
            },
        )
        try:
            with urlopen(request, timeout=30) as response:
                content = response.read()
        except HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            raise SyncError(
                f"HCP Terraform retornou HTTP {error.code} em {method} {path}: {detail}"
            ) from error
        except URLError as error:
            raise SyncError(
                f"Falha de conexão com o HCP Terraform em {method} {path}: {error.reason}"
            ) from error

        if not content:
            return {}
        result = json.loads(content)
        if not isinstance(result, dict):
            raise SyncError(f"Resposta inválida do HCP Terraform em {method} {path}.")
        return result

    def workspace_id(self, organization: str, workspace_name: str) -> str:
        response = self._request(
            "GET",
            "organizations/"
            f"{quote(organization, safe='')}/workspaces/{quote(workspace_name, safe='')}",
        )
        data = response.get("data")
        if not isinstance(data, dict) or not isinstance(data.get("id"), str):
            raise SyncError(f"Workspace HCP não encontrado: {workspace_name}.")
        return data["id"]

    def workspace_variables(self, workspace_id: str) -> list[Mapping[str, object]]:
        response = self._request(
            "GET", f"workspaces/{quote(workspace_id, safe='')}/vars?page%5Bsize%5D=100"
        )
        data = response.get("data")
        if not isinstance(data, list):
            raise SyncError(f"Lista de variáveis inválida para o workspace {workspace_id}.")
        return [item for item in data if isinstance(item, dict)]

    def set_workspace_variables(
        self,
        organization: str,
        workspace_name: str,
        definitions: Mapping[str, tuple[str, bool]],
    ) -> None:
        workspace_id = self.workspace_id(organization, workspace_name)
        variables = self.workspace_variables(workspace_id)

        for key, (value, hcl) in definitions.items():
            matches = [
                variable
                for variable in variables
                if _variable_attribute(variable, "key") == key
                and _variable_attribute(variable, "category") == "terraform"
            ]
            payload: dict[str, object] = {
                "data": {
                    "type": "vars",
                    "attributes": {
                        "key": key,
                        "value": value,
                        "description": DESCRIPTION,
                        "category": "terraform",
                        "hcl": hcl,
                        "sensitive": False,
                    },
                }
            }

            if not matches:
                self._request("POST", f"workspaces/{workspace_id}/vars", payload)
                continue

            variable_id = matches[0].get("id")
            if not isinstance(variable_id, str):
                raise SyncError(
                    f"Variável {key} sem identificador no workspace {workspace_name}."
                )
            data = payload["data"]
            if not isinstance(data, dict):
                raise SyncError("Payload interno inválido.")
            data["id"] = variable_id
            self._request(
                "PATCH", f"workspaces/{workspace_id}/vars/{variable_id}", payload
            )

            for duplicate in matches[1:]:
                duplicate_id = duplicate.get("id")
                if isinstance(duplicate_id, str):
                    self._request(
                        "DELETE", f"workspaces/{workspace_id}/vars/{duplicate_id}"
                    )


def _variable_attribute(variable: Mapping[str, object], name: str) -> object:
    attributes = variable.get("attributes")
    if not isinstance(attributes, dict):
        return None
    return attributes.get(name)


def _required_string(outputs: Mapping[str, object], name: str) -> str:
    value = _output_value(outputs, name)
    if not isinstance(value, str) or not value.strip():
        raise SyncError(f"Output obrigatório inválido: {name}.")
    return value


def _required_string_list(outputs: Mapping[str, object], name: str) -> list[str]:
    value = _output_value(outputs, name)
    if isinstance(value, str) or not isinstance(value, Sequence):
        raise SyncError(f"Output obrigatório inválido: {name}.")
    items = list(value)
    if not items or any(not isinstance(item, str) or not item.strip() for item in items):
        raise SyncError(f"Output obrigatório inválido: {name}.")
    return items


def _output_value(outputs: Mapping[str, object], name: str) -> object:
    output = outputs.get(name)
    if not isinstance(output, dict) or "value" not in output:
        raise SyncError(f"Output obrigatório ausente: {name}.")
    return output["value"]


def build_definitions(
    outputs: Mapping[str, object],
) -> tuple[dict[str, tuple[str, bool]], dict[str, tuple[str, bool]]]:
    vpc_id = _required_string(outputs, "vpc_id")
    private_subnet_ids = _required_string_list(outputs, "private_subnet_ids")
    security_group_id = _required_string(outputs, "eks_cluster_security_group_id")

    private_subnets_hcl = json.dumps(private_subnet_ids, separators=(",", ":"))
    security_groups_hcl = json.dumps([security_group_id], separators=(",", ":"))

    database = {
        "vpc_id": (vpc_id, False),
        "private_subnet_ids": (private_subnets_hcl, True),
        "allowed_security_group_ids": (security_groups_hcl, True),
    }
    auth = {
        "private_subnet_ids": (private_subnets_hcl, True),
        "lambda_security_group_id": (security_group_id, False),
    }
    return database, auth


def sync_outputs(
    client: HcpClient,
    outputs: Mapping[str, object],
    organization: str,
    database_workspace: str,
    auth_workspace: str,
) -> None:
    database, auth = build_definitions(outputs)
    client.set_workspace_variables(organization, database_workspace, database)
    client.set_workspace_variables(organization, auth_workspace, auth)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Sincroniza outputs de rede do Kubernetes com Database e Auth."
    )
    parser.add_argument("--outputs-file", type=Path, required=True)
    parser.add_argument(
        "--organization", default=os.environ.get("TF_CLOUD_ORGANIZATION")
    )
    parser.add_argument("--database-workspace", required=True)
    parser.add_argument("--auth-workspace", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.organization:
        raise SyncError("TF_CLOUD_ORGANIZATION não configurada.")

    token = os.environ.get("TF_API_TOKEN") or os.environ.get("TFC_TOKEN") or ""
    outputs = json.loads(args.outputs_file.read_text(encoding="utf-8"))
    if not isinstance(outputs, dict):
        raise SyncError("Arquivo de outputs Terraform inválido.")

    sync_outputs(
        HcpClient(token),
        outputs,
        args.organization,
        args.database_workspace,
        args.auth_workspace,
    )
    print(
        "Outputs de rede sincronizados com "
        f"{args.database_workspace} e {args.auth_workspace}."
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, json.JSONDecodeError, SyncError) as error:
        print(f"::error::{error}", file=sys.stderr)
        sys.exit(1)
