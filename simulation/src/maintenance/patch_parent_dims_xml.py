from __future__ import annotations

import shutil
import zipfile
from datetime import datetime
from pathlib import Path
import xml.etree.ElementTree as ET


SIM_DIR = Path(__file__).resolve().parents[2]
MODEL = SIM_DIR / "models" / "tractor_mu.slx"
CANDIDATE = SIM_DIR / "archive" / "tractor_mu_parent_dims_fixed_v2.slx"


def ptext(elem: ET.Element, name: str) -> str | None:
    for child in elem.findall("P"):
        if child.attrib.get("Name") == name:
            return child.text
    return None


def make_p(name: str, text: str) -> ET.Element:
    elem = ET.Element("P", {"Name": name})
    elem.text = text
    return elem


def main() -> None:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup = SIM_DIR / "archive" / f"tractor_mu.before_parent_dims_{stamp}.slx"
    shutil.copy2(MODEL, backup)
    shutil.copy2(MODEL, CANDIDATE)

    with zipfile.ZipFile(CANDIDATE, "r") as zin:
        members = {name: zin.read(name) for name in zin.namelist()}

    root_name = "simulink/systems/system_root.xml"
    root = ET.fromstring(members[root_name])

    # Remove the existing direct row-matrix fanout from Manual Switch SID 5082.
    for line in list(root.findall("Line")):
        src = ptext(line, "Src")
        dsts = [p.text for p in line.iter("P") if p.attrib.get("Name") == "Dst"]
        if src == "5082#out:1" and any(d in {"4648#in:2", "5699#in:2"} for d in dsts):
            root.remove(line)

    # Avoid duplicate insertion if this repair is run more than once.
    for block in list(root.findall("Block")):
        if block.attrib.get("Name") == "TCS_base_row_to_vector":
            root.remove(block)
    for line in list(root.findall("Line")):
        src = ptext(line, "Src")
        dsts = [p.text for p in line.iter("P") if p.attrib.get("Name") == "Dst"]
        if src in {"5082#out:1", "5720#out:1"} and any(
            d in {"5720#in:1", "4648#in:2", "5699#in:2"} for d in dsts
        ):
            root.remove(line)

    # Add a Simulink Reshape block that converts 1x4 to a 1-D 4-element vector.
    block = ET.Element("Block", {"BlockType": "Reshape", "Name": "TCS_base_row_to_vector", "SID": "5720"})
    block.append(make_p("Position", "[-300, 1742, -230, 1778]"))
    block.append(make_p("ZOrder", "100000"))
    block.append(ET.Element("PortCounts", {"in": "1", "out": "1"}))
    block.append(make_p("OutputDimensionality", "Customize"))
    block.append(make_p("OutputDimensions", "[4]"))
    root.insert(0, block)

    # Connect 5082 -> Reshape -> both Manual Switch inputs.
    line_in = ET.Element("Line")
    line_in.append(make_p("ZOrder", "16000"))
    line_in.append(make_p("Src", "5082#out:1"))
    line_in.append(make_p("Points", "[70, 0]"))
    line_in.append(make_p("Dst", "5720#in:1"))
    root.append(line_in)

    line_out = ET.Element("Line")
    line_out.append(make_p("ZOrder", "16001"))
    line_out.append(make_p("Src", "5720#out:1"))
    line_out.append(make_p("Points", "[70, 0]"))
    branch1 = ET.SubElement(line_out, "Branch")
    branch1.append(make_p("ZOrder", "16002"))
    branch1.append(make_p("Points", "[0, -1075]"))
    branch1.append(make_p("Dst", "4648#in:2"))
    branch2 = ET.SubElement(line_out, "Branch")
    branch2.append(make_p("ZOrder", "16003"))
    branch2.append(make_p("Points", "[0, -945]"))
    branch2.append(make_p("Dst", "5699#in:2"))
    root.append(line_out)

    # Keep the SID watermark above the inserted block.
    for child in root.findall("P"):
        if child.attrib.get("Name") == "SIDHighWatermark":
            child.text = "5720"

    members[root_name] = ET.tostring(root, encoding="utf-8", xml_declaration=True)

    tmp = CANDIDATE.with_suffix(".tmp.slx")
    with zipfile.ZipFile(tmp, "w", compression=zipfile.ZIP_DEFLATED) as zout:
        for name, data in members.items():
            zout.writestr(name, data)
    tmp.replace(CANDIDATE)

    print(f"BACKUP={backup}")
    print(f"CANDIDATE={CANDIDATE}")


if __name__ == "__main__":
    main()
