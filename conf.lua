
--- Callback function for configuring LOVE.
function love.conf(t)
	t.window.width	= 1200
	t.window.height	= 800

	t.console		= false

	io.stdout:setvbuf("no")
end
