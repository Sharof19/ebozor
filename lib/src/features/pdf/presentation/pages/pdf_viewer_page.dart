import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';

class PdfViewerPage extends StatefulWidget {
  const PdfViewerPage({super.key});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  String? _fileName;
  String? _filePath;
  String? _errorMessage;
  bool _isPicking = false;
  PdfControllerPinch? _pdfController;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    setState(() {
      _isPicking = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (result == null || result.files.isEmpty) {
        return;
      }
      final file = result.files.single;
      if (file.path == null) {
        throw Exception('Fayl yo\'li aniqlanmadi.');
      }

      final filePath = file.path!;
      final exists = await File(filePath).exists();
      if (!exists) {
        throw Exception('Tanlangan fayl qurilmada topilmadi.');
      }

      final pdfController =
          PdfControllerPinch(document: PdfDocument.openFile(filePath));
      setState(() {
        _pdfController?.dispose();
        _pdfController = pdfController;
        _fileName = file.name;
        _filePath = filePath;
        _totalPages = 0;
        _currentPage = 1;
      });
    } on PlatformException catch (e) {
      setState(() {
        _errorMessage = 'Fayl tanlash imkoniyati mavjud emas: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        _pdfController?.dispose();
        _pdfController = null;
        _filePath = null;
        _fileName = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('PDF ko\'rish'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _isPicking ? null : _pickPdf,
              icon: _isPicking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_open),
              label: Text(
                _isPicking ? 'Tanlanmoqda...' : 'PDF fayl tanlash',
              ),
            ),
            const SizedBox(height: 24),
            if (_fileName != null)
              Card(
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: Text(
                    _fileName!,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(_filePath ?? ''),
                ),
              ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Davom etish'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: _pdfController != null
                  ? Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: PdfViewPinch(
                              controller: _pdfController!,
                              onDocumentLoaded: (document) {
                                setState(() {
                                  _totalPages = document.pagesCount;
                                  _currentPage = 1;
                                });
                              },
                              onPageChanged: (page) {
                                setState(() {
                                  _currentPage = page;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sahifa $_currentPage / $_totalPages',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    )
                  : Center(
                      child: Text(
                        _filePath == null
                            ? 'PDF fayl tanlang.'
                            : 'Tanlangan faylni yuklab bo\'lmadi.',
                        style: const TextStyle(color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
