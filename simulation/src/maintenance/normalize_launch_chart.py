from copy import deepcopy
from pathlib import Path
import shutil
import xml.etree.ElementTree as ET
from zipfile import ZipFile

root = Path(__file__).resolve().parents[2]
model = root / "models" / "tractor_mu.slx"
backup = root / "archive" / "tractor_mu.pre_chart_normalize.slx"
source = root.parent / "_slx_inspect" / "after_wire" / "simulink" / "stateflow" / "chart_888.xml"


def prop(node, name):
    return next(p for p in node.findall("P") if p.get("Name") == name)


chart = ET.parse(source).getroot()
with ZipFile(model) as archive:
    chart_path = next(
        name for name in archive.namelist()
        if name.startswith("simulink/stateflow/chart_")
        and "驱动防滑模块/launch_state" in archive.read(name).decode("utf-8")
    )
    current = ET.fromstring(archive.read(chart_path))

chart.set("id", current.get("id"))
prop(chart, "decomposition").text = "SET_CHART"
children = chart.find("Children")
monitor = next(s for s in children.findall("state") if prop(s, "labelString").text.startswith("MONITOR"))
mode = next(s for s in children.findall("state") if prop(s, "labelString").text == "MODE")
for state, order, position in (
    (monitor, "1", "[40 40 520 760]"),
    (mode, "2", "[600 40 950 760]"),
):
    prop(state, "position").text = position
    execution = next((p for p in state.findall("P") if p.get("Name") == "executionOrder"), None)
    if execution is None:
        execution = ET.SubElement(state, "P", Name="executionOrder")
    execution.text = order

# MONITOR's data is shared with MODE, so keep it at chart scope.
monitor_children = monitor.find("Children")
if monitor_children is not None:
    monitor.remove(monitor_children)
old_children = current.find("Children")
for data in old_children.findall("data"):
    if data.get("name") in {
        "spin_on_t", "spin_clear_t", "no_move_t", "speed_on_t",
        "speed_off_t", "cons_bad_t", "desired_stage",
    }:
        children.append(deepcopy(data))

names = [
    "DISABLED", "START_PROBE", "NORMAL_LAUNCH", "HEAVY_NO_MOVE",
    "SINGLE_SPIN", "MULTI_SPIN", "WORK_PASS", "PROTECT",
]
codes = [255, 0, 1, 2, 3, 4, 5, 6]
for index, (name, code) in enumerate(zip(names, codes)):
    state = next(
        s for s in mode.find("Children").findall("state")
        if prop(s, "labelString").text.startswith(name)
    )
    prop(state, "labelString").text = f"{name}\nentry: stage = uint8({code});"
    col, row = index % 2, index // 2
    prop(state, "position").text = f"[{50 + 420 * col} {60 + 155 * row} 280 100]"

junction = mode.find("Children").find("junction")
prop(junction, "position").text = "[450 690 7]"

payload = ET.tostring(chart, encoding="utf-8", xml_declaration=True)
shutil.copy2(model, backup)
temporary = model.with_suffix(".normalized.tmp")
with ZipFile(model) as original, ZipFile(temporary, "w") as updated:
    for info in original.infolist():
        updated.writestr(info, payload if info.filename == chart_path else original.read(info.filename))
temporary.replace(model)
print(f"Normalized {chart_path}; backup: {backup}")
