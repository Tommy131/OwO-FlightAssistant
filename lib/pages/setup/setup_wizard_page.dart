/*
 *        _____   _          __  _____   _____   _       _____   _____
 *      /  _  \ | |        / / /  _  \ |  _  \ | |     /  _  \ /  ___|
 *      | | | | | |  __   / /  | | | | | |_| | | |     | | | | | |
 *      | | | | | | /  | / /   | | | | |  _  { | |     | | | | | |   _
 *      | |_| | | |/   |/ /    | |_| | | |_| | | |___  | |_| | | |_| |
 *      \_____/ |___/|___/     \_____/ |_____/ |_____| \_____/ \_____/
 *
 *  Copyright (c) 2023 by OwOTeam-DGMT (OwOBlog).
 * @Date         : 2025-10-22
 * @Author       : HanskiJay
 * @LastEditors  : HanskiJay
 * @LastEditTime : 2025-10-22
 * @E-Mail       : support@owoblog.com
 * @Telegram     : https://t.me/HanskiJay
 * @GitHub       : https://github.com/Tommy131
 */

import 'package:flutter/material.dart';
import '../../core/services/persistence/persistence_service.dart';
import 'steps/welcome_step.dart';
import 'steps/personalization_step.dart';
import 'steps/database_step.dart';
import 'steps/online_config_step.dart';
import 'steps/logging_step.dart';
import 'steps/completion_step.dart';

class SetupWizardPage extends StatefulWidget {
  final VoidCallback onSetupComplete;

  const SetupWizardPage({super.key, required this.onSetupComplete});

  @override
  State<SetupWizardPage> createState() => _SetupWizardPageState();
}

class _SetupWizardPageState extends State<SetupWizardPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  final List<Widget> _steps = [];

  @override
  void initState() {
    super.initState();
    _steps.addAll([
      WelcomeStep(onChoice: _handleWelcomeChoice),
      DatabaseStep(onNext: _nextStep),
      PersonalizationStep(onNext: _nextStep),
      OnlineConfigStep(onNext: _nextStep),
      LoggingStep(onNext: _nextStep),
      CompletionStep(onFinish: _finishSetup),
    ]);
  }

  void _handleWelcomeChoice(bool useWizard) {
    if (useWizard) {
      _nextStep();
    } else {
      // 如果跳过引导，直接进入数据库配置（最基础的配置）
      _pageController.animateToPage(
        1, // DatabaseStep
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishSetup() async {
    final persistence = PersistenceService();
    await persistence.setBool('is_setup_complete', true);
    widget.onSetupComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 进度指示器
            if (_currentStep > 0)
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _previousStep,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(child: _buildProgressBar()),
                  ],
                ),
              ),

            // 步骤内容
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentStep = index),
                children: _steps,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Center(
      child: Container(
        width: 300,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 300 * (_currentStep / (_steps.length - 1)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00F5FF), Color(0xFF7B2FFF)],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
