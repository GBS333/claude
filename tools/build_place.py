#!/usr/bin/env python3
"""Gera BrainrotTycoon.rbxlx (arquivo de jogo do Roblox Studio) com todos os scripts de src/.

Uso: python3 tools/build_place.py
Segue a mesma estrutura do default.project.json (Rojo):
  src/shared -> ReplicatedStorage.Shared
  src/server -> ServerScriptService.Server
  src/client -> StarterPlayer.StarterPlayerScripts.Client
  models/*.rbxmx -> ServerStorage.BrainrotModels (modelos 3D dos brainrots, sem scripts)
Arquivos: Nome.server.luau = Script, Nome.client.luau = LocalScript, Nome.luau = ModuleScript.
"""
import itertools
import os
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

SCRIPT_CLASSES = {"Script", "LocalScript", "ModuleScript"}

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


def strip_scripts(element):
    """Remove scripts (modelos da Toolbox podem ter vírus). Retorna quantos removeu."""
    removed = 0
    for child in list(element):
        if child.tag == "Item" and child.get("class") in SCRIPT_CLASSES:
            element.remove(child)
            removed += 1
        else:
            removed += strip_scripts(child)
    return removed


def load_models():
    """Lê models/*.rbxmx. Retorna (xml dos modelos, xml dos SharedStrings)."""
    folder = os.path.join(ROOT, "models")
    if not os.path.isdir(folder):
        return "", ""
    items, shared = [], []
    for entry in sorted(os.listdir(folder)):
        if not entry.lower().endswith(".rbxmx"):
            continue
        name = entry.rsplit(".", 1)[0]
        root = ET.parse(os.path.join(folder, entry)).getroot()
        # aceita um modelo por arquivo (TungTung.rbxmx) OU a pasta inteira salva (BrainrotModels.rbxmx)
        found = []
        for top in root.findall("Item"):
            if top.get("class") == "Model":
                found.append((top, name))
            elif top.get("class") == "Folder":
                for child in top.findall("Item"):
                    if child.get("class") == "Model":
                        found.append((child, None))
        if not found:
            print("  ignorado (sem Model):", entry)
            continue
        for model, rename in found:
            removed = strip_scripts(model)
            model_name = rename
            for prop in model.find("Properties").findall("string"):
                if prop.get("name") == "Name":
                    if rename:
                        prop.text = rename
                    model_name = prop.text
            items.append(ET.tostring(model, encoding="unicode"))
            print("  modelo:", model_name, "(scripts removidos: %d)" % removed if removed else "")
        for block in root.findall("SharedStrings"):
            shared.extend(ET.tostring(s, encoding="unicode") for s in block)
    shared_xml = "<SharedStrings>%s</SharedStrings>" % "".join(shared) if shared else ""
    return "".join(items), shared_xml


def main():
    src = os.path.join(ROOT, "src")
    models_xml, shared_xml = load_models()
    body = "".join([
        item("Workspace", "Workspace"),
        item("ReplicatedStorage", "ReplicatedStorage", from_dir(os.path.join(src, "shared"), "Shared")),
        item("ServerScriptService", "ServerScriptService", from_dir(os.path.join(src, "server"), "Server")),
        item("StarterPlayer", "StarterPlayer",
             item("StarterPlayerScripts", "StarterPlayerScripts", from_dir(os.path.join(src, "client"), "Client"))),
        item("ServerStorage", "ServerStorage", item("Folder", "BrainrotModels", models_xml)),
    ])
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
           + body + shared_xml + "</roblox>\n")
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(xml)
    print("Gerado:", OUT)


if __name__ == "__main__":
    main()
