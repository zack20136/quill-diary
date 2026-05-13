import 'package:flutter/material.dart';

class RecoveryPage extends StatelessWidget {
  const RecoveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recovery 骨架')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('這裡會放建立 Recovery Key、單篇解鎖與還原流程。'),
            SizedBox(height: 12),
            Text('目前先保留頁面入口，後續再接 crypto、storage 與 backup use cases。'),
          ],
        ),
      ),
    );
  }
}
