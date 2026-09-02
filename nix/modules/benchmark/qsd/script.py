import asyncio
import json
import os
import sys
from qemu.qmp import QMPClient
import argparse


def env_or_flag(key):
    return (
        {"default": os.environ.get(key)} if os.environ.get(key)
        else {"required": True}
    )


def iothread_id(vm_id: int, iothreads: int) -> str | None:
    if iothreads <= 0:
        return None
    return f"iothread{(vm_id - 1) % iothreads}"


async def _create(args) -> None:
    vm_id = args.vm_id
    qmp_socket = args.qmp_socket
    vhost_dir = args.vhost_dir
    iothreads = args.iothreads
    blockdev_args = json.loads(args.blockdev_args)
    export_args = json.loads(args.export_args)

    node = f"vm-{vm_id}"

    export_args_dict = dict(export_args)
    iothread = iothread_id(vm_id, iothreads)
    if iothread is not None:
        export_args_dict["iothread"] = iothread

    qmp = QMPClient()
    await qmp.connect(qmp_socket)
    try:
        await qmp.execute("blockdev-add", {
            "node-name": node,
            "image": node,
            "driver": "rbd",
            **blockdev_args,
        })
        await qmp.execute("block-export-add", {
            "id": node,
            "node-name": node,
            "addr": {
                "type": "unix",
                "path": f"{vhost_dir}/vm-{vm_id}.sock"
            },
            "writable": True,
            **export_args_dict,
        })
    finally:
        await qmp.disconnect()


async def _delete(args) -> None:
    vm_id = args.vm_id
    qmp_socket = args.qmp_socket

    node = f"vm-{vm_id}"

    qmp = QMPClient()
    await qmp.connect(qmp_socket)
    try:
        for cmd, cmd_args in [
            ("block-export-del", {"id": node}),
            ("blockdev-del", {"node-name": node}),
        ]:
            try:
                await qmp.execute(cmd, cmd_args)
            except Exception as err:
                print(f"{cmd}: {err}", file=sys.stderr)
    finally:
        await qmp.disconnect()


def create(args):
    asyncio.run(_create(args))


def delete(args):
    asyncio.run(_delete(args))


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(required=True)

    parser_create = subparsers.add_parser("create")
    parser_create.add_argument("--qmp-socket", **env_or_flag("QMP_SOCKET"))
    parser_create.add_argument("--vm-id", type=int, **env_or_flag("VM_ID"))
    parser_create.add_argument("--vhost-dir", **env_or_flag("VHOST_DIR"))
    parser_create.add_argument("--iothreads", type=int, **env_or_flag("IOTHREADS"))
    parser_create.add_argument("--blockdev-args", **env_or_flag("BLOCKDEV_ARGS"))
    parser_create.add_argument("--export-args", **env_or_flag("EXPORT_ARGS"))
    parser_create.set_defaults(func=create)

    parser_delete = subparsers.add_parser("delete")
    parser_delete.add_argument("--qmp-socket", **env_or_flag("QMP_SOCKET"))
    parser_delete.add_argument("--vm-id", type=int, **env_or_flag("VM_ID"))
    parser_delete.set_defaults(func=delete)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
