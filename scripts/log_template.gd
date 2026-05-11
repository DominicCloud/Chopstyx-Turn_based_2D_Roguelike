## Base class for all action log message templates.
## Each subclass groups related messages as @export_multiline strings.
## Use Godot's built-in String.format() to substitute {placeholders} at call sites.
## Example: LogTemplates.attack.kill.format({"source": s, "target": t})
class_name LogTemplate
extends Resource
