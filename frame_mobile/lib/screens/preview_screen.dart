import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/frame_renderer.dart';
import '../services/location_service.dart';

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  static const _includeTitleKey = 'include_title';
  static const _rememberTitleKey = 'remember_last_title';
  static const _lastTitleKey = 'last_title';

  final _titleController = TextEditingController();
  final _locationService = LocationService();
  final _frameRenderer = FrameRenderer();

  late final DateTime _capturedAt;
  String _locationLabel = 'Loading location...';
  bool _saving = false;
  bool _includeTitle = true;
  bool _rememberLastTitle = false;

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 72),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _capturedAt = DateTime.now();
    _loadTitlePreferences();
    _loadLocation();
  }

  Future<void> _loadTitlePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final includeTitle = prefs.getBool(_includeTitleKey) ?? true;
    final remember = prefs.getBool(_rememberTitleKey) ?? false;
    final lastTitle = prefs.getString(_lastTitleKey) ?? '';

    if (!mounted) return;
    setState(() {
      _includeTitle = includeTitle;
      _rememberLastTitle = remember;
      if (remember && lastTitle.trim().isNotEmpty) {
        _titleController.text = lastTitle;
      }
    });
  }

  Future<void> _persistTitlePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_includeTitleKey, _includeTitle);
    await prefs.setBool(_rememberTitleKey, _rememberLastTitle);
    if (_rememberLastTitle && _includeTitle) {
      await prefs.setString(_lastTitleKey, _titleController.text.trim());
    } else {
      await prefs.remove(_lastTitleKey);
    }
  }

  Future<void> _loadLocation() async {
    final result = await _locationService.getLocationLabel();
    if (!mounted) return;

    setState(() {
      _locationLabel = result.label;
    });
  }

  Future<void> _saveToGallery() async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      final photoBytes = await File(widget.imagePath).readAsBytes();
      final dateTimeText = DateFormat('yyyy-MM-dd HH:mm').format(_capturedAt);

      final outputBytes = await _frameRenderer.render(
        originalBytes: photoBytes,
        title: _includeTitle ? _titleController.text : '',
        includeTitle: _includeTitle,
        dateTimeText: dateTimeText,
        locationText: _locationLabel,
      );

      final hasPermission = await _ensurePhotoPermission();
      if (!hasPermission) {
        throw StateError('Gallery permission denied.');
      }

      final saveResult = await ImageGallerySaverPlus.saveImage(
        outputBytes,
        quality: 100,
        name: 'frame_${DateTime.now().millisecondsSinceEpoch}',
      );

      final success = (saveResult['isSuccess'] == true) ||
          (saveResult['filePath'] != null && saveResult['filePath'].toString().isNotEmpty);
      if (!success) {
        throw StateError('Could not save image to gallery.');
      }

      await _persistTitlePreferences();

      if (!mounted) return;
      _showMessage('Saved to gallery.');
      Navigator.of(context).pop();
    } catch (e) {
      _showMessage('Save failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<bool> _ensurePhotoPermission() async {
    if (Platform.isIOS) {
      final iosStatus = await Permission.photosAddOnly.request();
      return iosStatus.isGranted || iosStatus.isLimited;
    }

    if (Platform.isAndroid) {
      final photosStatus = await Permission.photos.request();
      if (photosStatus.isGranted || photosStatus.isLimited) {
        return true;
      }

      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }

    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateTimeText = DateFormat('yyyy-MM-dd HH:mm').format(_capturedAt);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Title & Save')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
              child: Container(
                  color: const Color(0xFFF8F4EC),
                  child: Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Image.file(
                            File(widget.imagePath),
                            fit: BoxFit.contain,
                            width: double.infinity,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Column(
                          children: [
                            if (_includeTitle) ...[
                              Text(
                                _titleController.text.trim().isEmpty
                                    ? 'Untitled'
                                    : _titleController.text.trim(),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              '$dateTimeText\n$_locationLabel',
                              style: const TextStyle(fontSize: 13),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SwitchListTile.adaptive(
              title: const Text('With title'),
              contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              value: _includeTitle,
              onChanged: (value) {
                setState(() {
                  _includeTitle = value;
                });
                _persistTitlePreferences();
              },
            ),
            if (_includeTitle)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    setState(() {});
                    if (_rememberLastTitle) {
                      _persistTitlePreferences();
                    }
                  },
                ),
              ),
            if (_includeTitle)
              SwitchListTile.adaptive(
                title: const Text('Remember last title'),
                contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                value: _rememberLastTitle,
                onChanged: (value) {
                  setState(() {
                    _rememberLastTitle = value;
                  });
                  _persistTitlePreferences();
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveToGallery,
                  icon: const Icon(Icons.save_alt_rounded),
                  label: Text(_saving ? 'Saving...' : 'Save to Phone'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
