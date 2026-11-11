class_name UITheme
extends RefCounted

## The shared UI theme. Every top-most Control (one whose parent isn't a Control) gets it explicitly, so a change to the theme
## reaches the whole UI from one place; theme overrides on individual nodes still win. Scenes assign it in the editor, UI built
## in code uses [method watch] or [method apply].

const BASE: Theme = preload("res://themes/base_theme.tres")


## Gives [param root]'s Control children [constant BASE] now and as they are added. Call it first in a CanvasLayer's _ready().
static func watch(root: Node) -> void:
	for child in root.get_children():
		apply(child)
	root.child_entered_tree.connect(UITheme.apply)


## Assigns [constant BASE] to [param node] if it is a Control without a theme.
static func apply(node: Node) -> void:
	if node is Control and node.theme == null:
		node.theme = BASE
