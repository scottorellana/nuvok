import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:markdown/markdown.dart' as md;

import '../../core/nuvok_library.dart';
import '../../core/locale_service.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  List<File> _notes = [];
  File? _current;
  final _controller = TextEditingController();
  Timer? _saveDebounce;
  bool _preview = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _saveNow();
    _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() => _notes = NuvokLibrary.instance.listNotes());
  }

  Future<void> _openNote(File f) async {
    await _saveNow();
    final text = await f.readAsString();
    setState(() {
      _current = f;
      _controller.text = text;
      _dirty = false;
      _preview = false;
    });
  }

  void _onChanged(String _) {
    _dirty = true;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 1), _saveNow);
  }

  Future<void> _saveNow() async {
    final f = _current;
    if (f == null || !_dirty) return;
    await f.writeAsString(_controller.text);
    _dirty = false;
  }

  Future<void> _newNote() async {
    final dir = NuvokLibrary.instance.notesDir;
    var i = 1;
    File f;
    do {
      f = File('${dir.path}/nota-$i.md');
      i++;
    } while (f.existsSync());
    await f.writeAsString('# Nueva nota\n\n');
    _refresh();
    await _openNote(f);
  }

  Future<void> _deleteNote(File f) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'deleteNoteQ')),
        content: Text(f.uri.pathSegments.last),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, 'cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr(context, 'delete'))),
        ],
      ),
    );
    if (confirm == true) {
      await f.delete();
      if (_current?.path == f.path) {
        _current = null;
        _controller.clear();
      }
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'notes')),
        actions: [
          if (_current != null)
            IconButton(
              tooltip: _preview ? 'Editar' : 'Vista previa',
              icon: Icon(_preview ? Icons.edit : Icons.visibility),
              onPressed: () async {
                await _saveNow();
                setState(() => _preview = !_preview);
              },
            ),
          IconButton(
            tooltip: 'Nueva nota',
            icon: const Icon(Icons.note_add),
            onPressed: _newNote,
          ),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 240,
            child: _notes.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Crea tu primera nota con +',
                          textAlign: TextAlign.center),
                    ),
                  )
                : ListView(
                    children: [
                      for (final f in _notes)
                        ListTile(
                          dense: true,
                          selected: _current?.path == f.path,
                          leading:
                              const Icon(Icons.description_outlined, size: 18),
                          title: Text(
                            f.uri.pathSegments.last,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _openNote(f),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => _deleteNote(f),
                          ),
                        ),
                    ],
                  ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _current == null
                ? Center(child: Text(tr(context, 'selectOrCreateNote')))
                : _preview
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: HtmlWidget(
                          md.markdownToHtml(_controller.text,
                              extensionSet: md.ExtensionSet.gitHubFlavored),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _controller,
                          onChanged: _onChanged,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          style: const TextStyle(
                              fontFamily: 'Menlo', fontSize: 14, height: 1.5),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: tr(context, 'writeMarkdown'),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
