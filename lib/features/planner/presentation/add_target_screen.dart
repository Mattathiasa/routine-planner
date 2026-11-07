import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../application/planner_controller.dart';
import '../data/planner_providers.dart';

/// A transient workflow, not a bookmarkable destination — pushed with a
/// plain `Navigator.push` rather than a new go_router route, consistent
/// with the router's existing 4-destination scope.
class AddTargetScreen extends ConsumerStatefulWidget {
  const AddTargetScreen({super.key});

  @override
  ConsumerState<AddTargetScreen> createState() => _AddTargetScreenState();
}

class _AddTargetScreenState extends ConsumerState<AddTargetScreen> {
  String _entityKind = 'character';
  String? _entityId;
  String? _linkedCharacterId;

  final _currentLevel = TextEditingController(text: '1');
  final _goalLevel = TextEditingController(text: '90');
  final _currentAscension = TextEditingController(text: '0');
  final _goalAscension = TextEditingController(text: '6');
  final _talentCurrent = List.generate(3, (_) => TextEditingController(text: '1'));
  final _talentGoal = List.generate(3, (_) => TextEditingController(text: '9'));

  @override
  void dispose() {
    _currentLevel.dispose();
    _goalLevel.dispose();
    _currentAscension.dispose();
    _goalAscension.dispose();
    for (final controller in _talentCurrent) {
      controller.dispose();
    }
    for (final controller in _talentGoal) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final entityId = _entityId;
    if (entityId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Pick a character or weapon.')));
      return;
    }

    final currentLevel = int.tryParse(_currentLevel.text);
    final goalLevel = int.tryParse(_goalLevel.text);
    final currentAscension = int.tryParse(_currentAscension.text);
    final goalAscension = int.tryParse(_goalAscension.text);
    if (currentLevel == null ||
        goalLevel == null ||
        currentAscension == null ||
        goalAscension == null ||
        currentLevel > goalLevel ||
        currentAscension > goalAscension) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Check the level and ascension values.')),
      );
      return;
    }

    List<({int current, int goal})>? talents;
    if (_entityKind == 'character') {
      talents = [];
      for (var i = 0; i < 3; i++) {
        final current = int.tryParse(_talentCurrent[i].text);
        final goal = int.tryParse(_talentGoal[i].text);
        if (current == null || goal == null || current > goal) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Check the talent level values.')),
          );
          return;
        }
        talents.add((current: current, goal: goal));
      }
    }

    await ref
        .read(plannerControllerProvider.notifier)
        .addTarget(
          entityKind: _entityKind,
          entityId: entityId,
          linkedCharacterId: _entityKind == 'weapon' ? _linkedCharacterId : null,
          currentLevel: currentLevel,
          goalLevel: goalLevel,
          currentAscension: currentAscension,
          goalAscension: goalAscension,
          talents: talents,
        );

    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final charactersAsync = ref.watch(allCharacterOptionsProvider);
    final weaponsAsync = ref.watch(allWeaponOptionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add target')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'character', label: Text('Character')),
                ButtonSegment(value: 'weapon', label: Text('Weapon')),
              ],
              selected: {_entityKind},
              onSelectionChanged: (selection) {
                setState(() {
                  _entityKind = selection.first;
                  _entityId = null;
                  _linkedCharacterId = null;
                });
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_entityKind == 'character')
              charactersAsync.when(
                data: (characters) => DropdownButtonFormField<String>(
                  initialValue: _entityId,
                  decoration: const InputDecoration(labelText: 'Character'),
                  items: [
                    for (final c in characters) DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (value) => setState(() => _entityId = value),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Text('Error: $error'),
              )
            else
              weaponsAsync.when(
                data: (weapons) => Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _entityId,
                      decoration: const InputDecoration(labelText: 'Weapon'),
                      items: [
                        for (final w in weapons) DropdownMenuItem(value: w.id, child: Text(w.name)),
                      ],
                      onChanged: (value) => setState(() => _entityId = value),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    charactersAsync.when(
                      data: (characters) => DropdownButtonFormField<String?>(
                        initialValue: _linkedCharacterId,
                        decoration: const InputDecoration(labelText: 'For (optional)'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('None')),
                          for (final c in characters)
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                        ],
                        onChanged: (value) => setState(() => _linkedCharacterId = value),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (error, stack) => Text('Error: $error'),
                    ),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Text('Error: $error'),
              ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(child: _NumberField(label: 'Current level', controller: _currentLevel)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _NumberField(label: 'Goal level', controller: _goalLevel)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _NumberField(label: 'Current ascension', controller: _currentAscension),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _NumberField(label: 'Goal ascension', controller: _goalAscension)),
              ],
            ),
            if (_entityKind == 'character') ...[
              const SizedBox(height: AppSpacing.xl),
              Text('Talents', style: Theme.of(context).textTheme.titleLarge),
              for (var i = 0; i < 3; i++) ...[
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(
                        label: 'Talent ${i + 1} current',
                        controller: _talentCurrent[i],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _NumberField(
                        label: 'Talent ${i + 1} goal',
                        controller: _talentGoal[i],
                      ),
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Padding(padding: EdgeInsets.all(12), child: Text('Add target')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
    );
  }
}
