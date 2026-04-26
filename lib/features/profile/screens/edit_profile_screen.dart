import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/providers/user_provider.dart';

/// Editable subset of the user profile. Mirrors the onboarding flow in
/// terms of fields, visualized as a single scrollable form.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late String _persona;
  late double _knowledgeLevel;
  late Set<String> _topics;
  late int _dailyGoal;

  static const _personas = [
    ('student', '👨‍🎓', 'Student'),
    ('professional', '👩‍💼', 'Professional'),
    ('curious', '🙃', 'Just Curious'),
  ];
  static const _levelLabels = ['Nothing', 'A Little', 'Quite a Bit', 'A Lot'];
  static const _levelKeys = ['nothing', 'a_little', 'quite_a_bit', 'a_lot'];
  static const _availableTopics = [
    ('ai_basics', 'AI Basics', '🤖'),
    ('machine_learning', 'Machine Learning', '🧠'),
    ('chatgpt_llms', 'ChatGPT & LLMs', '💬'),
    ('computer_vision', 'Computer Vision', '👁️'),
    ('generative_ai', 'Generative AI', '🎨'),
    ('ai_ethics', 'AI Ethics', '🔐'),
    ('data_science', 'Data Science', '📊'),
    ('ai_business', 'AI in Business', '⚙️'),
    ('prompt_engineering', 'Prompt Engineering', '🧑‍💻'),
    ('future_ai', 'Future of AI', '🚀'),
  ];
  static const _goalOptions = [5, 10, 15];

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider);
    _nameCtrl = TextEditingController(text: user.name ?? '');
    _emailCtrl = TextEditingController(text: user.email ?? '');
    _persona = user.persona;
    _knowledgeLevel =
        _levelKeys.indexOf(user.knowledgeLevel).clamp(0, 3).toDouble();
    _topics = user.selectedTopics.toSet();
    _dailyGoal = user.dailyGoal;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty && _topics.length >= 3;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(userProvider.notifier).updateProfileFields(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty
              ? null
              : _emailCtrl.text.trim(),
          dailyGoal: _dailyGoal,
          persona: _persona,
          knowledgeLevel: _levelKeys[_knowledgeLevel.round()],
          selectedTopics: _topics.toList(),
        );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: _canSave ? _save : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ----- Identity -----
            const _SectionLabel('Identity'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'How should we greet you?',
              ),
              maxLength: 30,
              onChanged: (_) => setState(() {}), // update save-button enable
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter a name'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return null;
                final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
                return ok ? null : 'Please enter a valid email';
              },
            ),

            // ----- Persona -----
            const SizedBox(height: 24),
            const _SectionLabel('I am a…'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _personas)
                  ChoiceChip(
                    selected: _persona == p.$1,
                    label: Text('${p.$2}  ${p.$3}'),
                    onSelected: (_) => setState(() => _persona = p.$1),
                  ),
              ],
            ),

            // ----- Knowledge level -----
            const SizedBox(height: 24),
            const _SectionLabel('My AI knowledge'),
            const SizedBox(height: 4),
            Text(
              _levelLabels[_knowledgeLevel.round()],
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Slider(
              value: _knowledgeLevel,
              min: 0,
              max: 3,
              divisions: 3,
              onChanged: (v) => setState(() => _knowledgeLevel = v),
            ),

            // ----- Topics -----
            const SizedBox(height: 16),
            _SectionLabel(
              'Topics I care about${_topics.length < 3 ? " (pick at least 3)" : ""}',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _availableTopics)
                  FilterChip(
                    selected: _topics.contains(t.$1),
                    label: Text('${t.$3}  ${t.$2}'),
                    onSelected: (v) => setState(() {
                      if (v) {
                        _topics.add(t.$1);
                      } else {
                        _topics.remove(t.$1);
                      }
                    }),
                  ),
              ],
            ),

            // ----- Daily goal -----
            const SizedBox(height: 24),
            const _SectionLabel('Daily goal'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in _goalOptions)
                  ChoiceChip(
                    selected: _dailyGoal == g,
                    label: Text('$g cards / day'),
                    onSelected: (_) => setState(() => _dailyGoal = g),
                  ),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}
