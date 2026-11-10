#!/usr/bin/env python3
"""Gera BrainrotTycoon.rbxlx (arquivo de jogo do Roblox Studio) com todos os scripts de src/.

Uso: python3 tools/build_place.py
Segue a mesma estrutura do default.project.json (Rojo):
  src/shared -> ReplicatedStorage.Shared
  src/server -> ServerScriptService.Server
  src/client -> StarterPlayer.StarterPlayerScripts.Client
Arquivos: Nome.server.luau = Script, Nome.client.luau = LocalScript, Nome.luau = ModuleScript.
"""
import itertools
import os
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "BrainrotTycoon.rbxlx")
_ids = itertools.count(1)


def ref():
    return "RBX%032X" % next(_ids)


def item(cls, name, children="", source=None):
    props = '<string name="Name">%s</string>' % escape(name)
    if source is not None:
        if "]]>" in source:
            raise ValueError("o código não pode conter ']]>'")
        props += '<ProtectedString name="Source"><![CDATA[%s]]></ProtectedString>' % source
    return '<Item class="%s" referent="%s"><Properties>%s</Properties>%s</Item>' % (cls, ref(), props, children)


def from_dir(path, name):
    children = []
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if os.path.isdir(full):
            children.append(from_dir(full, entry))
        elif entry.endswith(".luau") or entry.endswith(".lua"):
            with open(full, encoding="utf-8") as f:
                source = f.read()
            base = entry.rsplit(".", 1)[0]
            if base.endswith(".server"):
                children.append(item("Script", base[: -len(".server")], source=source))
            elif base.endswith(".client"):
                children.append(item("LocalScript", base[: -len(".client")], source=source))
            else:
                children.append(item("ModuleScript", base, source=source))
    return item("Folder", name, "".join(children))


def main():
    src = os.path.join(ROOT, "src")
    body = "".join([
        item("Workspace", "Workspace"),
        item("ReplicatedStorage", "ReplicatedStorage", from_dir(os.path.join(src, "shared"), "Shared")),
        item("ServerScriptService", "ServerScriptService", from_dir(os.path.join(src, "server"), "Server")),
        item("StarterPlayer", "StarterPlayer",
             item("StarterPlayerScripts", "StarterPlayerScripts", from_dir(os.path.join(src, "client"), "Client"))),
    ])
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
           + body + "</roblox>\n")
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(xml)
    print("Gerado:", OUT)


if __name__ == "__main__":
    main()
