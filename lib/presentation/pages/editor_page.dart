import 'package:flutter/material.dart';

class EditorPage extends StatelessWidget {
  const EditorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('編輯器骨架')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('這裡會放 metadata bar、title input、markdown body editor。'),
            SizedBox(height: 12),
            Text('目前只先建立頁面與路由，不接資料流與儲存邏輯。'),
          ],
        ),
      ),
    );
  }
}
