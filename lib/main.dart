import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
// not currently used
// import 'package:dropdown_search/dropdown_search.dart';

void main() {
  runApp(SSHEditorApp());
}

class SSHEditorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SSH Config Editor',
      theme: ThemeData.dark(),
      home: SSHConfigEditor(),
    );
  }
}

class SSHConfigEditor extends StatefulWidget {
  @override
  _SSHConfigEditorState createState() => _SSHConfigEditorState();
}

class _SSHConfigEditorState extends State<SSHConfigEditor> {
  String? configPath;
  Map<String, dynamic> globalOptions = {};
  List<Map<String, dynamic>> hostConfigs = [];
  TextEditingController _searchController = TextEditingController();
  List<bool> expandedStates = [];

  List<String> sshOptions = [
    // Basic Options
    "HostName",
    "User",
    "Port",
    // authentication options
    "IdentityFile",
    "PasswordAuthentication",
    "PubkeyAuthentication",
    "StrictHostKeyChecking",
    // Proxy options
    "ProxyCommand",
    "ProxyJump",
    "ForwardAgent",
    // Connection behavior
    "ConnectTimeout",
    "ServerAliveInterval",
    "ServerAliveCountMax",
    "Compression",
    "ControlMaster",
    "ControlPath",
    "ControlPersist",
    // Port forwarding"
    "LocalForward",
    "RemoteForward",
    "DynamicForward",
    // X11 Forwarding
    "ForwardX11",
    "ForwardX11Trusted",
    // Host-specific options
    "SendEnv",
    "SetEnv",
    "LogLevel",
    // Other stuff
    "UserKnownHostsFile",
    "BatchMode",
    "CheckHostIP",
    "AddressFamily",
    "BindAddress",
    "GlobalKnownHostsFile",
    "HostKeyAlgorithms",
    "KbdInteractiveAuthentication",
    "KbdInteractiveDevices",
    "MACs",
    "PreferredAuthentications",
    "Protocol",
    "RekeyLimit",
    "VerifyHostKeyDNS",
    "VisualHostKey",
    "XAuthLocation"
  ];

  void _selectConfigFile() async {
    String? selectedFile = await FilePicker.platform
        .pickFiles(
          dialogTitle: "Select SSH Config File",
          type: FileType.custom,
          allowedExtensions: ['config'],
          initialDirectory: Platform.environment['HOME'],
        )
        ?.then((result) => result?.files.single.path);

    if (selectedFile != null) {
      setState(() {
        configPath = selectedFile;
      });
      _loadConfig();
    }
  }

  void _loadConfig() async {
    if (configPath == null) return;
    File configFile = File(configPath!);
    if (await configFile.exists()) {
      List<String> lines = await configFile.readAsLines();
      _parseConfig(lines);
    }
  }

  void _reloadConfig() async {
    expandedStates.clear();
    if (configPath == null) return;
    File configFile = File(configPath!);
    if (await configFile.exists()) {
      List<String> lines = await configFile.readAsLines();
      _parseConfig(lines);
    }
  }

  List<Map<String, dynamic>> _filteredHosts() {
    String query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      return hostConfigs;
    }
    return hostConfigs
        .where((host) => host.entries.any((entry) =>
            entry.key.toLowerCase().contains(query) ||
            (entry.value?.toString().toLowerCase() ?? '').contains(query)))
        .toList();
  }

  void _parseConfig(List<String> lines) {
    globalOptions.clear();
    hostConfigs.clear();
    expandedStates.clear();

    Map<String, dynamic> currentHost = {};
    String? currentHostName;

    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      List<String> parts = line.split(RegExp(r'\s+'));
      if (parts[0] == 'Host') {
        if (currentHostName != null) {
          hostConfigs.add({'Host': currentHostName, ...currentHost});
          expandedStates.add(false);
        }
        currentHostName = parts[1];
        currentHost = {};
      } else {
        if (currentHostName != null) {
          currentHost[parts[0]] = parts.sublist(1).join(' ');
        } else {
          globalOptions[parts[0]] = parts.sublist(1).join(' ');
        }
      }
    }
    if (currentHostName != null) {
      hostConfigs.add({'Host': currentHostName, ...currentHost});
      expandedStates.add(false);
    }

    setState(() {});
  }

  void _previewConfig() {
    String configPreview = _generateConfigString();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Preview Config"),
          content: SingleChildScrollView(
            child: SelectableText(configPreview),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: configPreview));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Copied to clipboard")),
                );
              },
              child: Text("Copy to Clipboard"),
            ),
            IconButton(
              icon: Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _saveConfig() async {
    if (configPath == null) return;
    File configFile = File(configPath!);
    List<String> lines = [];
    globalOptions.forEach((key, value) {
      lines.add('$key $value');
    });
    for (var host in hostConfigs) {
      lines.add('\nHost ${host['Host']}');
      host.forEach((key, value) {
        if (key != 'Host') lines.add('  $key $value');
      });
    }
    await configFile.writeAsString(lines.join('\n'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Config saved successfully')),
    );
  }

  String _generateConfigString() {
    List<String> lines = [];
    globalOptions.forEach((key, value) {
      lines.add('$key $value');
    });
    for (var host in hostConfigs) {
      lines.add('\nHost ${host['Host']}');
      host.forEach((key, value) {
        if (key == '' || value == '') return;
        if (key != 'Host') lines.add('  $key $value');
      });
    }
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('SSH Config Editor')),
      body: Padding(
        padding: EdgeInsets.all(8.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _selectConfigFile,
              child: Text('Select SSH Config File'),
            ),
            if (configPath != null) Text('Selected File: $configPath'),
            Padding(
                padding:
                    const EdgeInsets.all(16.0), // Adjust the padding as needed
                child: ElevatedButton(
                  onPressed: () => setState(() {
                    hostConfigs.insert(0, {
                      'Host': 'NewHost_${DateTime.now().millisecondsSinceEpoch}'
                    });
                    expandedStates.insert(0, true); // expanded by default
                  }),
                  child: Text('+ Add New Host'),
                )),
            TextField(
              controller: _searchController,
              decoration:
                  InputDecoration(labelText: 'Search Hosts and Options'),
              onChanged: (value) => setState(() {}),
            ),
            Expanded(
              child: ReorderableListView.builder(
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = hostConfigs.removeAt(oldIndex);
                    final wasExpanded = expandedStates.removeAt(oldIndex);
                    hostConfigs.insert(newIndex, item);
                    expandedStates.insert(newIndex, wasExpanded);
                  });
                },
                itemCount: _filteredHosts().length,
                itemBuilder: (context, index) {
                  var host = _filteredHosts()[index];
                  return Card(
                    key: ValueKey(host['Host']),
                    child: ExpansionTile(
                      initiallyExpanded: expandedStates[index],
                      onExpansionChanged: (isExpanded) {
                        setState(() {
                          expandedStates[index] = isExpanded;
                        });
                      },
                      title: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (value) =>
                                  hostConfigs[index]['Host'] = value,
                              controller:
                                  TextEditingController(text: host['Host']),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Host',
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.copy, color: Colors.blue),
                            onPressed: () {
                              // copy host to clipboard
                              Clipboard.setData(
                                  ClipboardData(text: host['Host']));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Copied to clipboard")),
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              // Handle delete action
                              setState(() {
                                hostConfigs.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                      children: [
                        ...host.entries
                            .where((entry) => entry.key != 'Host')
                            .map((entry) {
                          return Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 4.0),
                            child: Row(
                              children: [
                                DropdownButton<String>(
                                  value: sshOptions.contains(entry.key)
                                      ? entry.key
                                      : null,
                                  hint: Text('Select Option'),
                                  onChanged: (newKey) {
                                    if (newKey != null) {
                                      setState(() {
                                        hostConfigs[index][newKey] =
                                            hostConfigs[index]
                                                .remove(entry.key);
                                      });
                                    }
                                  },
                                  items: sshOptions.map((option) {
                                    return DropdownMenuItem(
                                      value: option,
                                      child: Text(option),
                                    );
                                  }).toList(),
                                ),
                                Expanded(
                                  child: TextField(
                                    onChanged: (value) =>
                                        hostConfigs[index][entry.key] = value,
                                    controller: TextEditingController(
                                        text: sshOptions.contains(entry.key)
                                            ? entry.value
                                            : ''),
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.copy, color: Colors.blue),
                                  onPressed: () {
                                    // copy host to clipboard
                                    Clipboard.setData(ClipboardData(
                                        text: hostConfigs[index][entry.key]));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text("Copied to clipboard")),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => setState(() =>
                                      hostConfigs[index].remove(entry.key)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        TextButton(
                          onPressed: () => setState(() => hostConfigs[index][
                                  'NewOption_${DateTime.now().millisecondsSinceEpoch}'] =
                              ''),
                          child: Text('+ New Option'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Padding(
                    padding: const EdgeInsets.all(
                        16.0), // Adjust the padding as needed
                    child: ElevatedButton(
                      onPressed: _reloadConfig,
                      child: Text('Discard changes and reload config'),
                      style: ButtonStyle(
                          foregroundColor:
                              WidgetStateProperty.all(Colors.black),
                          backgroundColor:
                              WidgetStateProperty.all(Colors.deepOrange)),
                    )),
                ElevatedButton(
                  onPressed: _previewConfig,
                  child: Text('Preview Config'),
                ),
                ElevatedButton(
                  onPressed: _saveConfig,
                  child: Text('Save Config'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
