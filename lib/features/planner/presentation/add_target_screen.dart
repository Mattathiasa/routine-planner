import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../application/planner_controller.dart';
import '../application/planner_view_models.dart';
import '../data/planner_providers.dart';
import 'entity_avatar.dart';
import 'rarity_chip.dart';
import '../../../core/widgets/app_status_views.dart';

/// A transient workflow, not a bookmarkable destination — pushed with a
/// plain `Navigator.push` rather than a new go_router route, consistent
/// with the router's existing 4-destination scope. With [editing] set it
/// becomes the target *detail*: prefilled fields, a fixed entity header
/// (the card avatar Hero-flies into it), save-in-place, and removal with
/// an undo snackbar instead of a confirm dialog.
class AddTargetScreen extends ConsumerStatefulWidget {
  const AddTargetScreen({super.key, this.editing});

  final TargetCardData? editing;

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
  final _talentCurrent = List.generate(
    3,
    (_) => TextEditingController(text: '1'),
  );
  final _talentGoal = List.generate(3, (_) => TextEditingController(text: '9'));

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing == null) return;
    _entityKind = editing.isWeapon ? 'weapon' : 'character';
    _entityId = editing.entityId;
    _linkedCharacterId = editing.linkedCharacterId;
    _currentLevel.text = '${editing.currentLevel}';
    _goalLevel.text = '${editing.goalLevel}';
    _currentAscension.text = '${editing.currentAscension}';
    _goalAscension.text = '${editing.goalAscension}';
    final talents = editing.talents;
    if (talents != null) {
      for (var i = 0; i < 3; i++) {
        _talentCurrent[i].text = '${talents[i].current}';
        _talentGoal[i].text = '${talents[i].goal}';
      }
    }
  }

  Future<void> _removeTarget(TargetCardData editing) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = ref.read(plannerControllerProvider.notifier);

    unawaited(HapticFeedback.mediumImpact());
    await controller.removeTarget(editing.id);
    if (mounted) navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${editing.name} removed from plan'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => controller.restoreTarget(editing.id),
        ),
      ),
    );
  }

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
      messenger.showSnackBar(
        const SnackBar(content: Text('Pick a character or weapon.')),
      );
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

    final controller = ref.read(plannerControllerProvider.notifier);
    final editing = widget.editing;
    if (editing != null) {
      await controller.updateTarget(
        id: editing.id,
        entityKind: _entityKind,
        entityId: entityId,
        linkedCharacterId: _entityKind == 'weapon' ? _linkedCharacterId : null,
        currentLevel: currentLevel,
        goalLevel: goalLevel,
        currentAscension: currentAscension,
        goalAscension: goalAscension,
        talents: talents,
      );
    } else {
      await controller.addTarget(
        entityKind: _entityKind,
        entityId: entityId,
        linkedCharacterId: _entityKind == 'weapon' ? _linkedCharacterId : null,
        currentLevel: currentLevel,
        goalLevel: goalLevel,
        currentAscension: currentAscension,
        goalAscension: goalAscension,
        talents: talents,
      );
    }

    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final charactersAsync = ref.watch(allCharacterOptionsProvider);
    final weaponsAsync = ref.watch(allWeaponOptionsProvider);

    final editing = widget.editing;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing != null ? 'Edit target' : 'Add target'),
        actions: [
          if (editing != null)
            IconButton(
              tooltip: 'Remove target',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _removeTarget(editing),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            if (editing != null)
              Row(
                children: [
                  Hero(
                    tag: 'target-avatar-${editing.id}',
                    child: EntityAvatar(
                      isWeapon: editing.isWeapon,
                      name: editing.name,
                      element: editing.element,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.mlg),
                  Flexible(
                    child: Text(
                      editing.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  RarityChip(rarity: editing.rarity),
                ],
              )
            else
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
            if (editing != null)
              const SizedBox.shrink()
            else if (_entityKind == 'character')
              charactersAsync.when(
                data: (characters) => DropdownButtonFormField<String>(
                  initialValue: _entityId,
                  decoration: const InputDecoration(labelText: 'Character'),
                  items: [
                    for (final c in characters)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (value) => setState(() => _entityId = value),
                ),
                loading: () => const AppLoadingView(),
                error: (error, stack) => AppErrorView(error: error),
              )
            else
              weaponsAsync.when(
                data: (weapons) => Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _entityId,
                      decoration: const InputDecoration(labelText: 'Weapon'),
                      items: [
                        for (final w in weapons)
                          DropdownMenuItem(value: w.id, child: Text(w.name)),
                      ],
                      onChanged: (value) => setState(() => _entityId = value),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    charactersAsync.when(
                      data: (characters) => DropdownButtonFormField<String?>(
                        initialValue: _linkedCharacterId,
                        decoration: const InputDecoration(
                          labelText: 'For (optional)',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('None'),
                          ),
                          for (final c in characters)
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                        ],
                        onChanged: (value) =>
                            setState(() => _linkedCharacterId = value),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (error, stack) => AppErrorView(error: error),
                    ),
                  ],
                ),
                loading: () => const AppLoadingView(),
                error: (error, stack) => AppErrorView(error: error),
              ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    label: 'Current level',
                    controller: _currentLevel,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _NumberField(
                    label: 'Goal level',
                    controller: _goalLevel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    label: 'Current ascension',
                    controller: _currentAscension,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _NumberField(
                    label: 'Goal ascension',
                    controller: _goalAscension,
                  ),
                ),
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
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(editing != null ? 'Save changes' : 'Add target'),
                ),
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
