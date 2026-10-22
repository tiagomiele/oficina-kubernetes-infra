import importlib.util
import unittest
from collections.abc import Mapping
from pathlib import Path


SCRIPT_PATH = Path(__file__).parents[1] / "scripts" / "sync-network-outputs.py"
SPEC = importlib.util.spec_from_file_location("sync_network_outputs", SCRIPT_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Não foi possível carregar sync-network-outputs.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class RecordingClient:
    def __init__(self) -> None:
        self.calls: list[
            tuple[str, str, dict[str, tuple[str, bool]]]
        ] = []

    def set_workspace_variables(
        self,
        organization: str,
        workspace_name: str,
        definitions: dict[str, tuple[str, bool]],
    ) -> None:
        self.calls.append((organization, workspace_name, definitions))


class RecordingHcpClient(MODULE.HcpClient):
    def __init__(self, variables: list[Mapping[str, object]]) -> None:
        super().__init__("token")
        self.variables = variables
        self.requests: list[tuple[str, str, Mapping[str, object] | None]] = []

    def _request(
        self, method: str, path: str, payload: Mapping[str, object] | None = None
    ) -> Mapping[str, object]:
        self.requests.append((method, path, payload))
        if path.startswith("organizations/"):
            return {"data": {"id": "ws-123"}}
        if method == "GET" and "/vars" in path:
            return {"data": self.variables}
        return {}


class SyncNetworkOutputsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.outputs = {
            "vpc_id": {"value": "vpc-123"},
            "private_subnet_ids": {"value": ["subnet-a", "subnet-b"]},
            "eks_cluster_security_group_id": {"value": "sg-123"},
        }

    def test_builds_database_and_auth_variables(self) -> None:
        database, auth = MODULE.build_definitions(self.outputs)

        self.assertEqual(database["vpc_id"], ("vpc-123", False))
        self.assertEqual(
            database["private_subnet_ids"], ('["subnet-a","subnet-b"]', True)
        )
        self.assertEqual(
            database["allowed_security_group_ids"], ('["sg-123"]', True)
        )
        self.assertEqual(
            auth,
            {
                "private_subnet_ids": ('["subnet-a","subnet-b"]', True),
                "lambda_security_group_id": ("sg-123", False),
            },
        )

    def test_syncs_both_downstream_workspaces(self) -> None:
        client = RecordingClient()

        MODULE.sync_outputs(
            client,
            self.outputs,
            "oficina-org",
            "oficina-database-homolog",
            "oficina-auth-homolog",
        )

        self.assertEqual(len(client.calls), 2)
        self.assertEqual(client.calls[0][0:2], ("oficina-org", "oficina-database-homolog"))
        self.assertEqual(client.calls[1][0:2], ("oficina-org", "oficina-auth-homolog"))

    def test_upserts_variables_and_removes_duplicates(self) -> None:
        client = RecordingHcpClient(
            [
                {
                    "id": "var-primary",
                    "attributes": {"key": "vpc_id", "category": "terraform"},
                },
                {
                    "id": "var-duplicate",
                    "attributes": {"key": "vpc_id", "category": "terraform"},
                },
            ]
        )

        client.set_workspace_variables(
            "oficina-org",
            "oficina-database-homolog",
            {
                "vpc_id": ("vpc-123", False),
                "private_subnet_ids": ('["subnet-a"]', True),
            },
        )

        operations = [(method, path) for method, path, _ in client.requests]
        self.assertIn(
            ("PATCH", "workspaces/ws-123/vars/var-primary"), operations
        )
        self.assertIn(
            ("DELETE", "workspaces/ws-123/vars/var-duplicate"), operations
        )
        self.assertIn(("POST", "workspaces/ws-123/vars"), operations)

    def test_rejects_missing_output(self) -> None:
        del self.outputs["vpc_id"]

        with self.assertRaisesRegex(MODULE.SyncError, "vpc_id"):
            MODULE.build_definitions(self.outputs)

    def test_rejects_empty_private_subnets(self) -> None:
        self.outputs["private_subnet_ids"] = {"value": []}

        with self.assertRaisesRegex(MODULE.SyncError, "private_subnet_ids"):
            MODULE.build_definitions(self.outputs)


if __name__ == "__main__":
    unittest.main()
