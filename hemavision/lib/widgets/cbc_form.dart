import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../utils/validators.dart';

class CBCParameter {
  final String key;
  final String label;
  final String range;
  final String unit;
  final double min;
  final double max;
  final double multiplier;
  final String convertedUnit;

  const CBCParameter(
    this.key,
    this.label,
    this.range,
    this.unit,
    this.min,
    this.max, {
    this.multiplier = 1,
    this.convertedUnit = '',
  });
}

class CBCFormWidget extends StatefulWidget {
  final Map<String, TextEditingController> controllers;
  final VoidCallback onSubmit;

  const CBCFormWidget({
    super.key,
    required this.controllers,
    required this.onSubmit,
  });

  static const parameters = [
    CBCParameter(
      'wbc',
      'WBC Count',
      '4.5-11.0',
      '10^3/uL',
      4.5,
      11.0,
      multiplier: 1000,
      convertedUnit: 'cells/uL',
    ),
    CBCParameter('rbc', 'RBC Count', '4.5-5.9', '10^6/uL', 4.5, 5.9),
    CBCParameter(
      'hemoglobin',
      'Hemoglobin',
      '13.5-17.5',
      'g/dL',
      13.5,
      17.5,
      multiplier: 10,
      convertedUnit: 'g/L',
    ),
    CBCParameter('hematocrit', 'Hematocrit', '41-53', '%', 41, 53),
    CBCParameter('mcv', 'MCV', '80-100', 'fL', 80, 100),
    CBCParameter('mch', 'MCH', '27-33', 'pg', 27, 33),
    CBCParameter('mchc', 'MCHC', '32-36', 'g/dL', 32, 36),
    CBCParameter(
      'platelets',
      'Platelets',
      '150-400',
      '10^3/uL',
      150,
      400,
      multiplier: 1000,
      convertedUnit: 'cells/uL',
    ),
    CBCParameter('neutrophils', 'Neutrophils', '40-70', '%', 40, 70),
    CBCParameter('lymphocytes', 'Lymphocytes', '20-40', '%', 20, 40),
    CBCParameter('monocytes', 'Monocytes', '2-8', '%', 2, 8),
    CBCParameter('eosinophils', 'Eosinophils', '1-4', '%', 1, 4),
    CBCParameter('basophils', 'Basophils', '0.5-1', '%', .5, 1),
  ];

  @override
  State<CBCFormWidget> createState() => _CBCFormWidgetState();
}

class _CBCFormWidgetState extends State<CBCFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final Set<String> _converted = {};

  Color _borderColor(CBCParameter p) {
    final value = double.tryParse(widget.controllers[p.key]?.text.trim() ?? '');
    if (value == null) return AppColors.bgSurface;
    return value >= p.min && value <= p.max
        ? AppColors.successGreen
        : AppColors.accentRed;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          for (var i = 0; i < CBCFormWidget.parameters.length; i += 2)
            Row(
              children: [
                Expanded(child: _field(CBCFormWidget.parameters[i])),
                const SizedBox(width: 12),
                if (i + 1 < CBCFormWidget.parameters.length)
                  Expanded(child: _field(CBCFormWidget.parameters[i + 1]))
                else
                  const Spacer(),
              ],
            ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [AppColors.primaryTeal, AppColors.primaryLight],
              ),
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              onPressed: () {
                if (_formKey.currentState?.validate() ?? false)
                  widget.onSubmit();
              },
              icon: const Icon(Icons.analytics_rounded),
              label: const Text('Analyze Now'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(CBCParameter p) {
    final controller = widget.controllers[p.key]!;
    final value = double.tryParse(controller.text.trim());
    final convertedText = value == null || p.convertedUnit.isEmpty
        ? ''
        : '${(value * p.multiplier).toStringAsFixed(value * p.multiplier > 100 ? 0 : 1)} ${p.convertedUnit}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 7),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderColor(p)),
            ),
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              validator: (v) => Validators.numeric(v, p.label),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: p.range,
                suffixIcon: p.convertedUnit.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          p.unit,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Convert unit',
                        icon: const Icon(Icons.swap_horiz_rounded),
                        onPressed: () => setState(
                          () => _converted.contains(p.key)
                              ? _converted.remove(p.key)
                              : _converted.add(p.key),
                        ),
                      ),
              ),
            ),
          ),
          AnimatedContainer(
            height: _converted.contains(p.key) && convertedText.isNotEmpty
                ? 24
                : 0,
            duration: const Duration(milliseconds: 250),
            alignment: Alignment.centerLeft,
            child: Text(
              convertedText,
              style: const TextStyle(
                color: AppColors.primaryLight,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
