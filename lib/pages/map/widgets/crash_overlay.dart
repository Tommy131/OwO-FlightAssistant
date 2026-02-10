import 'package:flutter/material.dart';
import 'dart:math';

class CrashOverlay extends StatelessWidget {
  final VoidCallback onDismiss;

  const CrashOverlay({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final quotes = [
      "飞机是挺硬的，但地面更硬点。",
      "你是在练习降落吗？还是在垂直钻井？",
      "至少你降落在地球上了。",
      "模拟器的好处就是：你还能再点一次重置。",
      "这次降落可以打 1 分，满分是 100 分。",
      "塔台问你是否需要地毯，你给了他们一个坑。",
      "航空公司可能会对你的续约表示担忧。",
      "这大概就是所谓的 '一次性飞行器' 吧。",
      "RIP (Really Interesting Pilot)",
      "由于你出色的飞行技巧，地面已经成功拦截了你。",
      "刚才那不是降落，那是受控坠毁。",
      "恭喜你，你已经成为了大地母亲的一部分。",
    ];

    final randomQuote = quotes[Random().nextInt(quotes.length)];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withValues(alpha: 0.9),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 80,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 20),
              const Text(
                '你 炸 了',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'CRITICAL MISSION FAILURE',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  '"$randomQuote"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 60),
              ElevatedButton(
                onPressed: onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('接受现实 (重置)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
