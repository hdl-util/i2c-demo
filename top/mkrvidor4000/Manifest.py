files = [
    "mkrvidor4000_top.sv",
]

modules = {
    "git": [
        "git@github.com:hdl-util/hdmi.git::master",
        "git@github.com:hdl-util/i2c.git::master",
        "git@github.com:hdl-util/vga-text-mode.git::master"
    ]
}

fetchto = "../../ip_cores"
