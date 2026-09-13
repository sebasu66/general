class_name ShipComputerLibrary
extends RefCounted


static func build_terminal_text(snapshot: Dictionary) -> String:
    var engine: Dictionary = snapshot.get("engine", {})
    var power: Dictionary = snapshot.get("power", {})
    var thrusters: Array = snapshot.get("thrusters", [])
    var connections: Array = snapshot.get("connections", [])

    var text := ""
    text += "SHIP CENTRAL COMPUTER / LIVE COMPONENT BUS\n"
    text += "==============================================================\n"
    text += " [PILOT SEAT] --control events--> [CENTRAL COMPUTER]\n"
    text += "                                      |\n"
    text += "                   +------------------+------------------+\n"
    text += "                   |                                     |\n"
    text += "                   v                                     v\n"
    text += "             [4 VECTOR NOZZLES] <---power--- [MAIN ENGINE]\n"
    text += "                                                   |\n"
    text += "                                             energy request\n"
    text += "                                                   v\n"
    text += "                                      [SOLAR SENSOR + BATTERY]\n"
    text += "\n"
    text += "ENGINE  input:%s   requested %5.1f%%   actual %5.1f%%   drain %5.1f u/s\n" % [
        String(engine.get("required_power_type", &"?")),
        float(engine.get("requested_output_ratio", 0.0)) * 100.0,
        float(engine.get("actual_output_ratio", 0.0)) * 100.0,
        float(engine.get("consumption_per_second", 0.0)),
    ]
    text += "POWER   output:%s  battery %5.1f%%   solar +%5.1f u/s   motor -%5.1f u/s   net %+5.1f\n" % [
        String(power.get("power_type", &"?")),
        float(power.get("battery_ratio", 0.0)) * 100.0,
        float(power.get("solar_generation_per_second", 0.0)),
        float(power.get("consumption_per_second", 0.0)),
        float(power.get("net_per_second", 0.0)),
    ]
    text += "\nNOZZLES\n"
    for item: Dictionary in thrusters:
        text += "  %-3s  output %5.1f%%   thrust %6.1f N   gimbal %4.1f deg\n" % [
            String(item.get("id", &"?")),
            float(item.get("throttle", 0.0)) * 100.0,
            float(item.get("thrust", 0.0)),
            float(item.get("gimbal_degrees", 0.0)),
        ]

    text += "\nACTIVE CONNECTIONS\n"
    for connection: Variant in connections:
        text += "  * %s\n" % String(connection)

    text += "\n[T / X] CLOSE TERMINAL\n"
    return text
