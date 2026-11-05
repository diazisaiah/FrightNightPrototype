class_name WebField
extends LineEdit
## A text field that works in the browser build (2026-11-05). A Godot LineEdit
## there can't take Ctrl+V or open a phone's keyboard (the browser only does
## those for its own inputs, tapped by a real finger). So on the web a real
## HTML input sits exactly over the field and follows it, hides with it, and
## hands its text back each frame. Everywhere else this is a plain LineEdit.
## Also here: copy() and paste for the clipboard, which the web build's own
## clipboard calls can't reach from inside the page.

const JS := """
(function () {
	if (window.fnSync) { return; }
	window.fnFields = {};
	function copyText(t) {
		var ta = document.createElement('textarea');
		ta.value = t;
		ta.style.cssText = 'position:fixed;left:-1000px;top:0;opacity:0;';
		document.body.appendChild(ta);
		ta.select();
		try { document.execCommand('copy'); } catch (e) {}
		document.body.removeChild(ta);
	}
	window.fnCopy = function (t) {
		try {
			if (navigator.clipboard && navigator.clipboard.writeText) {
				navigator.clipboard.writeText(t).catch(function () { copyText(t); });
				return;
			}
		} catch (e) {}
		copyText(t);
	};
	window.fnPaste = function (id) {
		try {
			navigator.clipboard.readText().then(function (t) {
				var el = window.fnFields[id];
				if (el) { el.value = t; }
			}, function () {});
		} catch (e) {}
	};
	window.fnSync = function (id, x, y, w, h, vis, setv, ph, ro) {
		var el = window.fnFields[id];
		if (!el) {
			el = document.createElement('input');
			el.type = 'text';
			el.setAttribute('autocomplete', 'off');
			el.setAttribute('autocapitalize', 'off');
			el.setAttribute('autocorrect', 'off');
			el.spellcheck = false;
			el.style.cssText = 'position:fixed;z-index:9999;box-sizing:border-box;background:#0f0b14;' +
				'color:#f1ecf8;border:1px solid rgba(255,255,255,0.28);border-radius:8px;padding:0 12px;' +
				'font-family:sans-serif;outline:none;display:none;';
			el.addEventListener('focus', function () { el.style.borderColor = '#ffc447'; if (el.readOnly) { el.select(); } });
			el.addEventListener('blur', function () { el.style.borderColor = 'rgba(255,255,255,0.28)'; });
			el.addEventListener('keydown', function (e) { if (e.key === 'Enter') { el.dataset.sub = '1'; } });
			document.body.appendChild(el);
			window.fnFields[id] = el;
		}
		var sub = '';
		if (el.dataset.sub === '1') { sub = '\u0001'; el.dataset.sub = ''; }
		el.style.display = vis ? 'block' : 'none';
		if (!vis) { return el.value; }
		var c = document.querySelector('canvas');
		if (!c) { return el.value; }
		var r = c.getBoundingClientRect();
		el.style.left = (r.left + x * r.width) + 'px';
		el.style.top = (r.top + y * r.height) + 'px';
		el.style.width = (w * r.width) + 'px';
		el.style.height = (h * r.height) + 'px';
		el.style.fontSize = Math.max(16, h * r.height * 0.42) + 'px';
		if (setv !== null) { el.value = setv; }
		if (el.placeholder !== ph) { el.placeholder = ph; }
		el.readOnly = ro;
		return sub + el.value;
	};
	window.fnRemove = function (id) {
		var el = window.fnFields[id];
		if (el) { el.parentNode.removeChild(el); delete window.fnFields[id]; }
	};
})();
"""

static var _next_id := 0
static var _ready_js := false

var _web := false
var _id := ""
## The text both sides last agreed on.
var _seen := ""
var _push := true


func _ready() -> void:
	_web = OS.has_feature("web")
	if not _web:
		return
	if not _ready_js:
		JavaScriptBridge.eval(JS, true)
		_ready_js = true
	_next_id += 1
	_id = "fnf%d" % _next_id
	tree_exiting.connect(func() -> void: JavaScriptBridge.eval("window.fnRemove('%s')" % _id, true))
	# The Godot field underneath is just a placeholder for layout.
	modulate.a = 0.0


func _process(_delta: float) -> void:
	if not _web:
		return
	var shown := is_visible_in_tree()
	var view := get_viewport().get_visible_rect().size
	var rect := get_global_rect()
	if text != _seen:
		_push = true
		_seen = text
	var value: Variant = JavaScriptBridge.eval("window.fnSync('%s', %f, %f, %f, %f, %s, %s, %s, %s)" % [
		_id, rect.position.x / view.x, rect.position.y / view.y, rect.size.x / view.x, rect.size.y / view.y,
		"true" if shown else "false", JSON.stringify(text) if _push else "null", JSON.stringify(placeholder_text),
		"true" if not editable else "false"], true)
	_push = false
	if shown and value is String:
		var got: String = value
		var submitted := got.begins_with("")
		if submitted:
			got = got.substr(1)
		if got != text:
			text = got
			_seen = got
			text_changed.emit(got)
		if submitted:
			text_submitted.emit(got)


## Fills the field from the clipboard (the Paste button).
func paste_from_clipboard() -> void:
	if _web:
		JavaScriptBridge.eval("window.fnPaste('%s')" % _id, true)
	else:
		var clip := DisplayServer.clipboard_get()
		if clip != "":
			text = clip
			text_changed.emit(clip)


## Puts text on the player's clipboard (works in the browser build too).
static func copy(code: String) -> void:
	if OS.has_feature("web"):
		if not _ready_js:
			JavaScriptBridge.eval(JS, true)
			_ready_js = true
		JavaScriptBridge.eval("window.fnCopy(%s)" % JSON.stringify(code), true)
	else:
		DisplayServer.clipboard_set(code)
