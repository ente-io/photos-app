import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import "package:photos/generated/l10n.dart";

class MemoryUploadingPage extends StatefulWidget {
  const MemoryUploadingPage({
    Key? key,
  }) : super(key: key);

  @override
  State<MemoryUploadingPage> createState() => _MemoryUploadingPageState();
}

class _MemoryUploadingPageState extends State<MemoryUploadingPage> {
  final Logger _logger = Logger("MemoryUploadingPage");

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          S.of(context).allMemoriesPreserved,
        ),
      ),
      body: _getBody(),
    );
  }

  Widget _getBody() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [],
      ),
    );
  }
}
