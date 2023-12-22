local ansicolors = require("ansicolors") -- https://github.com/kikito/ansicolors.lua
local ll = require("logging")
require "logging.console"

-- configure the default logger used when testing
ll.defaultLogger(ll.console {
	logLevel = ll.DEBUG,
	destination = "stderr",
	timestampPattern = "%y-%m-%d %H:%M:%S",
	logPatterns = {
		[ll.DEBUG] = ansicolors("%date%{cyan} %level %message %{reset}(%source)\n"),
		[ll.INFO] = ansicolors("%date %level %message\n"),
		[ll.WARN] = ansicolors("%date%{yellow} %level %message\n"),
		[ll.ERROR] = ansicolors("%date%{red bright} %level %message %{reset}(%source)\n"),
		[ll.FATAL] = ansicolors("%date%{magenta bright} %level %message %{reset}(%source)\n"),
	}
})
