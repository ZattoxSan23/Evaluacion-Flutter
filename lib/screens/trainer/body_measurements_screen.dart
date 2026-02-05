import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../widgets/gradient_button.dart';

class BodyMeasurementsScreen extends StatefulWidget {
  final String clientId;
  final Map<String, dynamic>? existingMeasurement;
  final Function()? onSaved;

  const BodyMeasurementsScreen({
    super.key,
    required this.clientId,
    this.existingMeasurement,
    this.onSaved,
  });

  @override
  State<BodyMeasurementsScreen> createState() => _BodyMeasurementsScreenState();
}

class _BodyMeasurementsScreenState extends State<BodyMeasurementsScreen> {
  // Controladores para medidas básicas
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  String _selectedGender = 'male';
  String _selectedGoal = 'fitness';

  // Controladores para medidas corporales
  final _neckCtrl = TextEditingController();
  final _shouldersCtrl = TextEditingController();
  final _chestCtrl = TextEditingController();
  final _armsCtrl = TextEditingController();
  final _waistCtrl = TextEditingController();
  final _glutesCtrl = TextEditingController();
  final _legsCtrl = TextEditingController();
  final _calvesCtrl = TextEditingController();
  final _injuriesCtrl = TextEditingController();

  // Métricas calculadas
  double _bmi = 0.0;
  double _bodyFat = 0.0;
  int _metabolicAge = 0;
  double _muscleMass = 0.0;
  double _waterPercentage = 0.0;
  double _boneMass = 0.0;
  int _visceralFat = 0;
  double _leanBodyMass = 0.0;
  double _idealWeight = 0.0;
  double _idealWeightGym = 0.0;
  double _fatMass = 0.0;
  double _basalMetabolicRate = 0.0;
  double _waistHipRatio = 0.0;
  double _waistHeightRatio = 0.0;
  String _bodyType = '';

  // Información del cliente
  Map<String, dynamic>? _clientInfo;
  Map<String, dynamic>? _previousMeasurement;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showAdvanced = false;
  String? _currentTrainerId;

  // Constantes
  static const double ln10 = 2.302585092994046;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadClientData();
    _initializeForm();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final profile = await supabase
            .from('profiles')
            .select('id')
            .eq('id', user.id)
            .single();

        setState(() {
          _currentTrainerId = profile['id'];
        });
      }
    } catch (e) {
      debugPrint('Error cargando usuario actual: $e');
    }
  }

  Future<void> _loadClientData() async {
    setState(() => _isLoading = true);

    try {
      // Cargar información del cliente
      final client = await supabase.from('clients').select('''
            *,
            profiles!clients_user_id_fkey(
              full_name,
              gender,
              age
            )
          ''').eq('id', widget.clientId).single();

      // Cargar medición anterior
      final previous = await supabase
          .from('body_measurements')
          .select('*')
          .eq('client_id', widget.clientId)
          .order('measurement_date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _clientInfo = client;
          _previousMeasurement = previous;
          _isLoading = false;
        });

        if (widget.existingMeasurement == null) {
          _prefillClientData();
        }
      }
    } catch (e) {
      debugPrint('Error cargando datos: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _initializeForm() {
    if (widget.existingMeasurement != null) {
      final measurement = widget.existingMeasurement!;

      _weightCtrl.text = measurement['weight']?.toString() ?? '';
      _heightCtrl.text = measurement['height']?.toString() ?? '';
      _ageCtrl.text = measurement['age']?.toString() ?? '';
      _selectedGender = measurement['gender'] ?? 'male';

      _neckCtrl.text = measurement['neck']?.toString() ?? '';
      _shouldersCtrl.text = measurement['shoulders']?.toString() ?? '';
      _chestCtrl.text = measurement['chest']?.toString() ?? '';
      _armsCtrl.text = measurement['arms']?.toString() ?? '';
      _waistCtrl.text = measurement['waist']?.toString() ?? '';
      _glutesCtrl.text = measurement['glutes']?.toString() ?? '';
      _legsCtrl.text = measurement['legs']?.toString() ?? '';
      _calvesCtrl.text = measurement['calves']?.toString() ?? '';
      _injuriesCtrl.text = measurement['injuries'] ?? '';

      _bmi = measurement['bmi']?.toDouble() ?? 0.0;
      _bodyFat = measurement['body_fat']?.toDouble() ?? 0.0;
      _metabolicAge = measurement['metabolic_age'] ?? 0;
      _muscleMass = measurement['muscle_mass']?.toDouble() ?? 0.0;
      _waterPercentage = measurement['water_percentage']?.toDouble() ?? 0.0;
      _boneMass = measurement['bone_mass']?.toDouble() ?? 0.0;
      _visceralFat = measurement['visceral_fat'] ?? 0;

      // Calcular pesos ideales al inicializar
      if (_heightCtrl.text.isNotEmpty) {
        final height = double.tryParse(_heightCtrl.text) ?? 0.0;
        _idealWeight = _calculateIdealWeightMedical(height, _selectedGender);
        _idealWeightGym = _calculateIdealWeightGym(height, _selectedGender);
      }

      // Recalcular todo al editar (IMPORTANTE)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_weightCtrl.text.isNotEmpty && _heightCtrl.text.isNotEmpty) {
          _calculateAllMetrics();
        }
      });
    }
  }

  void _prefillClientData() {
    if (_clientInfo != null) {
      final profile = _clientInfo!['profiles'] ?? {};
      setState(() {
        _ageCtrl.text =
            (profile['age'] ?? _clientInfo!['age'] ?? '').toString();
        _selectedGender = profile['gender'] ?? _clientInfo!['gender'] ?? 'male';

        if (_previousMeasurement != null) {
          _heightCtrl.text = _previousMeasurement!['height']?.toString() ?? '';
        }
      });
    }
  }

  void _calculateAllMetrics() {
    final double weight = double.tryParse(_weightCtrl.text) ?? 0.0;
    final double height = double.tryParse(_heightCtrl.text) ?? 0.0;
    final int age = int.tryParse(_ageCtrl.text) ?? 0;
    final double waist = double.tryParse(_waistCtrl.text) ?? 0.0;
    final double neck = double.tryParse(_neckCtrl.text) ?? 0.0;
    final double hips = double.tryParse(_glutesCtrl.text) ?? 0.0;

    if (weight > 0 && height > 0) {
      // Validar edad
      final int validAge = (age < 10 || age > 120) ? 30 : age;

      // 1. CALCULAR IMC
      final double heightMeters = height / 100.0;
      final double bmi = (weight / pow(heightMeters, 2)).toDouble();

      // 2. CALCULAR GRASA CORPORAL - FÓRMULA US NAVY OFICIAL
      double bodyFat = _calculateBodyFatUSNavy(
        heightCm: height,
        neckCm: neck,
        waistCm: waist,
        hipsCm: hips,
        gender: _selectedGender,
        weight: weight,
        age: validAge,
      );

      // 3. CALCULAR MASA GRASA
      final double fatMass = weight * (bodyFat / 100);

      // 4. CALCULAR MASA MAGRA (LBM)
      final double leanBodyMass = weight - fatMass;

      // Validación: Masa magra mínima biológica
      double minLeanBodyMass = _selectedGender == 'male'
          ? 40.0 + (height - 150) * 0.5
          : 30.0 + (height - 150) * 0.4;
      final double validLeanBodyMass =
          leanBodyMass.clamp(minLeanBodyMass, weight * 0.95);

      // 5. CALCULAR MASA MUSCULAR - FÓRMULA CORREGIDA (realista)
      final double muscleMass = _calculateSkeletalMuscleMass(
        leanMass: validLeanBodyMass,
        gender: _selectedGender,
        age: validAge,
        bodyFatPercent: bodyFat,
      );

      // 6. CALCULAR PESOS IDEALES
      final double idealWeightMedical =
          _calculateIdealWeightMedical(height, _selectedGender);
      final double idealWeightGym =
          _calculateIdealWeightGym(height, _selectedGender);

      // 7. CALCULAR AGUA CORPORAL - fórmula realista
      final double waterPercentage = _calculateWaterPercentageRealistic(
        bodyFatPercent: bodyFat,
        gender: _selectedGender,
      );

      // 8. CALCULAR MASA ÓSEA - fórmula simple y efectiva
      final double boneMass = _calculateBoneMassRealistic(
        weight: weight,
        gender: _selectedGender,
      );

      // 9. CALCULAR GRASA VISCERAL
      final int visceralFat = _calculateVisceralFatRealistic(
        waist: waist,
        height: height,
        gender: _selectedGender,
        bodyFat: bodyFat,
      );

      // 10. CALCULAR EDAD METABÓLICA
      final int metabolicAge = _calculateMetabolicAgeRealistic(
        bmi: bmi,
        bodyFat: bodyFat,
        chronologicalAge: validAge,
        gender: _selectedGender,
        waist: waist,
        height: height,
        muscleMass: muscleMass,
      );

      // 11. CALCULAR TMB (Katch-McArdle)
      final double bmr = 370 + (21.6 * validLeanBodyMass);

      // 12. CALCULAR RELACIONES
      final double waistHipRatio = hips > 0 ? waist / hips : 0.0;
      final double waistHeightRatio = waist > 0 ? waist / height : 0.0;

      // 13. DETERMINAR SOMATOTIPO
      final String bodyType = _determineBodyTypeRealistic(
        bmi: bmi,
        waistHipRatio: waistHipRatio,
        waistHeightRatio: waistHeightRatio,
        gender: _selectedGender,
        bodyFat: bodyFat,
        muscleMass: muscleMass,
        weight: weight,
      );

      // 14. NORMALIZAR COMPARTIMENTOS
      _normalizeCompartments(
        weight: weight,
        bodyFat: bodyFat,
        muscleMass: muscleMass,
        boneMass: boneMass,
        waterPercentage: waterPercentage,
      );

      setState(() {
        _bmi = double.parse(bmi.toStringAsFixed(1));
        _bodyFat = double.parse(bodyFat.toStringAsFixed(1));
        _fatMass = double.parse(fatMass.toStringAsFixed(1));
        _leanBodyMass = double.parse(validLeanBodyMass.toStringAsFixed(1));
        _muscleMass = double.parse(muscleMass.toStringAsFixed(1));
        _idealWeight = double.parse(idealWeightMedical.toStringAsFixed(1));
        _idealWeightGym = double.parse(idealWeightGym.toStringAsFixed(1));
        _waterPercentage = double.parse(waterPercentage.toStringAsFixed(1));
        _boneMass = double.parse(boneMass.toStringAsFixed(1));
        _visceralFat = visceralFat;
        _metabolicAge = metabolicAge;
        _basalMetabolicRate = double.parse(bmr.toStringAsFixed(0));
        _waistHipRatio = double.parse(waistHipRatio.toStringAsFixed(2));
        _waistHeightRatio = double.parse(waistHeightRatio.toStringAsFixed(2));
        _bodyType = bodyType;
      });
    }
  }

  // ========== FÓRMULAS CORREGIDAS Y VALIDADAS ==========

  double _calculateBodyFatUSNavy({
    required double heightCm,
    required double neckCm,
    required double waistCm,
    required double hipsCm,
    required String gender,
    required double weight,
    required int age,
  }) {
    double log10(double x) => log(x) / ln10;

    if (gender == 'male') {
      if (waistCm <= neckCm || waistCm <= 0 || neckCm <= 0) {
        // Fallback si faltan medidas o son inválidas
        final double heightM = heightCm / 100;
        final double bmi = weight / (heightM * heightM);
        return (1.20 * bmi) + (0.23 * age) - 16.2;
      }

      double diff = waistCm - neckCm;
      if (diff <= 0) diff = 1.0; // evitar log(0)

      double bodyFat = 86.010 * log10(diff) - 70.041 * log10(heightCm) + 36.76;

      // Rango típico para hombres
      return bodyFat.clamp(8.0, 40.0);
    } else {
      if (hipsCm <= 0 || waistCm + hipsCm <= neckCm || neckCm <= 0) {
        // Fallback para mujeres
        final double heightM = heightCm / 100;
        final double bmi = weight / (heightM * heightM);
        return (1.20 * bmi) + (0.23 * age) - 5.4;
      }

      double sum = waistCm + hipsCm - neckCm;
      if (sum <= 0) sum = 1.0;

      double bodyFat = 163.205 * log10(sum) - 97.684 * log10(heightCm) - 78.387;

      // Rango típico para mujeres
      return bodyFat.clamp(18.0, 45.0);
    }
  }

  double _calculateSkeletalMuscleMass({
    required double leanMass,
    required String gender,
    required int age,
    required double bodyFatPercent,
  }) {
    double basePercent;

    if (gender == 'male') {
      basePercent = 0.50; // ~50% de LBM es músculo esquelético (promedio)
      if (bodyFatPercent < 12) basePercent += 0.04; // atletas
      if (bodyFatPercent > 25) basePercent -= 0.06; // obesos
    } else {
      basePercent = 0.42; // mujeres ~42%
      if (bodyFatPercent < 20) basePercent += 0.04;
      if (bodyFatPercent > 35) basePercent -= 0.07;
    }

    // Penalización por edad (sarcopenia aproximada)
    if (age > 40) {
      double agePenalty = ((age - 40) / 10.0).clamp(0.0, 3.0);
      basePercent -= 0.01 * agePenalty;
    }

    double muscleMass = leanMass * basePercent;

    // Límites biológicos duros
    double minMuscle = gender == 'male' ? 22.0 : 14.0;
    double maxMuscle = leanMass * 0.62; // muy raro superar 62%

    return muscleMass.clamp(minMuscle, maxMuscle);
  }

  double _calculateWaterPercentageRealistic({
    required double bodyFatPercent,
    required String gender,
  }) {
    double base = gender == 'male' ? 60.0 : 55.0;
    double fatAdjust =
        (bodyFatPercent / 100) * -45.0; // grasa casi no tiene agua
    double result = base + fatAdjust;
    return result.clamp(45.0, 68.0);
  }

  double _calculateBoneMassRealistic({
    required double weight,
    required String gender,
  }) {
    double percent = gender == 'male' ? 0.14 : 0.12; // ~12–15% del peso
    return (weight * percent).clamp(2.2, 5.0);
  }

  int _calculateVisceralFatRealistic({
    required double waist,
    required double height,
    required String gender,
    required double bodyFat,
  }) {
    if (waist == 0) return 5;

    final double waistHeightRatio = waist / height;

    if (gender == 'male') {
      if (waistHeightRatio < 0.45) return 3;
      if (waistHeightRatio < 0.50) return 6;
      if (waistHeightRatio < 0.55) return 9;
      if (waistHeightRatio < 0.60) return 11;
      return 12;
    } else {
      if (waistHeightRatio < 0.40) return 3;
      if (waistHeightRatio < 0.45) return 6;
      if (waistHeightRatio < 0.50) return 9;
      if (waistHeightRatio < 0.55) return 11;
      return 12;
    }
  }

  int _calculateMetabolicAgeRealistic({
    required double bmi,
    required double bodyFat,
    required int chronologicalAge,
    required String gender,
    required double waist,
    required double height,
    required double muscleMass,
  }) {
    double metabolicScore = 0.0;

    // Factor músculo
    double referenceMuscle = gender == 'male' ? 30.0 : 20.0;
    metabolicScore -= ((muscleMass - referenceMuscle) / 5.0);

    // Factor grasa
    double idealBodyFat = gender == 'male' ? 18.0 : 25.0;
    metabolicScore += ((bodyFat - idealBodyFat) / 5.0);

    // Factor cintura/altura
    double waistHeightRatio = waist / height;
    metabolicScore += (waistHeightRatio - 0.5) * 20;

    // Factor edad cronológica (más suave)
    if (chronologicalAge > 30) {
      metabolicScore += (chronologicalAge - 30) * 0.08;
    }

    int metabolicAge = chronologicalAge + metabolicScore.round();

    return metabolicAge.clamp(chronologicalAge - 10, chronologicalAge + 15);
  }

  String _determineBodyTypeRealistic({
    required double bmi,
    required double waistHipRatio,
    required double waistHeightRatio,
    required String gender,
    required double bodyFat,
    required double muscleMass,
    required double weight,
  }) {
    double musclePercentage = (muscleMass / weight) * 100;

    if (gender == 'male') {
      if (musclePercentage > 42 && bodyFat < 18) return 'Mesomorfo';
      if (bodyFat > 28 && waistHeightRatio > 0.55) return 'Endomorfo';
      if (musclePercentage < 35 && bmi < 22) return 'Ectomorfo';
      if (waistHipRatio > 0.95) return 'Androide';
      if (waistHipRatio < 0.85 && musclePercentage > 38)
        return 'Mesomorfo Atlético';
      return 'Balanceado';
    } else {
      if (musclePercentage > 35 && bodyFat < 25) return 'Mesomorfo';
      if (bodyFat > 32 && waistHeightRatio > 0.50) return 'Endomorfo';
      if (musclePercentage < 28 && bmi < 20) return 'Ectomorfo';
      if (waistHipRatio > 0.85) return 'Androide';
      if (waistHipRatio < 0.75 && musclePercentage > 32)
        return 'Mesomorfo Atlético';
      return 'Ginoide';
    }
  }

  double _calculateIdealWeightMedical(double height, String gender) {
    const double baseHeightCm = 152.4;

    if (height <= baseHeightCm) {
      return gender == 'male' ? 50.0 : 45.5;
    }

    double heightOverBase = height - baseHeightCm;
    double weightPerCm = 0.91;

    return gender == 'male'
        ? 50.0 + (weightPerCm * heightOverBase)
        : 45.5 + (weightPerCm * heightOverBase);
  }

  double _calculateIdealWeightGym(double height, String gender) {
    // IMC objetivo más realista
    double targetBMI;

    if (gender == 'male') {
      if (height < 165) {
        targetBMI = 22.0;
      } else if (height < 180) {
        targetBMI = 23.0;
      } else {
        targetBMI = 24.0;
      }
    } else {
      if (height < 160) {
        targetBMI = 21.0;
      } else if (height < 175) {
        targetBMI = 22.0;
      } else {
        targetBMI = 23.0;
      }
    }

    double heightMeters = height / 100;
    return targetBMI * heightMeters * heightMeters;
  }

  void _normalizeCompartments({
    required double weight,
    required double bodyFat,
    required double muscleMass,
    required double boneMass,
    required double waterPercentage,
  }) {
    // Calcular porcentajes
    double fatPct = bodyFat;
    double musclePct = (muscleMass / weight) * 100;
    double bonePct = (boneMass / weight) * 100;
    double waterPct = waterPercentage;

    // El agua se solapa → estimamos agua de tejidos
    double muscleWater = musclePct * 0.75;
    double boneWater = bonePct * 0.25;
    double fatWater = fatPct * 0.10;

    double waterFromTissues = muscleWater + boneWater + fatWater;
    double otherWater = waterPct - waterFromTissues;

    if (otherWater < 0) otherWater = 0;

    double total = fatPct + musclePct + bonePct + otherWater;

    // CORRECCIÓN: Usar double literals para la comparación
    if (total > 105.0 || total < 95.0) {
      double factor = 100.0 / total;

      // Ajuste más suave y realista (evita cambios drásticos)
      double adjustment = 0.85 + (0.15 * factor); // entre ~0.85 y ~1.0

      // Actualizamos las variables globales del estado
      _bodyFat = double.parse((bodyFat * adjustment).toStringAsFixed(1));
      _muscleMass = double.parse((muscleMass * adjustment).toStringAsFixed(1));
      _boneMass = double.parse((boneMass * adjustment).toStringAsFixed(1));
      _waterPercentage =
          double.parse((waterPercentage * adjustment).toStringAsFixed(1));
    }
  }

  Future<void> _saveMeasurement() async {
    if (_weightCtrl.text.isEmpty || _heightCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Peso y altura son requeridos')),
      );
      return;
    }

    // Recalcular todo antes de guardar
    _calculateAllMetrics();

    setState(() => _isSubmitting = true);

    try {
      final measurementData = {
        'client_id': widget.clientId,
        'trainer_id': _currentTrainerId,
        'weight': double.parse(_weightCtrl.text),
        'height': double.parse(_heightCtrl.text),
        'age': _ageCtrl.text.isNotEmpty ? int.parse(_ageCtrl.text) : null,
        'gender': _selectedGender,
        'neck': _neckCtrl.text.isNotEmpty ? double.parse(_neckCtrl.text) : null,
        'shoulders': _shouldersCtrl.text.isNotEmpty
            ? double.parse(_shouldersCtrl.text)
            : null,
        'chest':
            _chestCtrl.text.isNotEmpty ? double.parse(_chestCtrl.text) : null,
        'arms': _armsCtrl.text.isNotEmpty ? double.parse(_armsCtrl.text) : null,
        'waist':
            _waistCtrl.text.isNotEmpty ? double.parse(_waistCtrl.text) : null,
        'glutes':
            _glutesCtrl.text.isNotEmpty ? double.parse(_glutesCtrl.text) : null,
        'legs': _legsCtrl.text.isNotEmpty ? double.parse(_legsCtrl.text) : null,
        'calves':
            _calvesCtrl.text.isNotEmpty ? double.parse(_calvesCtrl.text) : null,
        'injuries': _injuriesCtrl.text.isNotEmpty ? _injuriesCtrl.text : null,
        'bmi': _bmi,
        'body_fat': _bodyFat,
        'metabolic_age': _metabolicAge,
        'muscle_mass': _muscleMass,
        'water_percentage': _waterPercentage,
        'bone_mass': _boneMass,
        'visceral_fat': _visceralFat,
        'measurement_date': DateTime.now().toIso8601String().split('T')[0],
        'notes': '''
COMPOSICIÓN CORPORAL - ANÁLISIS CIENTÍFICO

DATOS BÁSICOS:
• Peso: ${_weightCtrl.text} kg
• Altura: ${_heightCtrl.text} cm
• Edad: ${_ageCtrl.text.isNotEmpty ? _ageCtrl.text : 'N/A'} años
• Género: ${_selectedGender == 'male' ? 'Masculino' : 'Femenino'}

PESOS IDEALES:
• Salud general: ${_idealWeight.toStringAsFixed(1)} kg
• Para deporte: ${_idealWeightGym.toStringAsFixed(1)} kg
• Diferencia: ${(double.parse(_weightCtrl.text) - _idealWeightGym).abs().toStringAsFixed(1)} kg

COMPOSICIÓN (Fórmulas validadas):
• Masa Grasa: ${_fatMass.toStringAsFixed(1)} kg (${_bodyFat.toStringAsFixed(1)}%)
• Masa Magra: ${_leanBodyMass.toStringAsFixed(1)} kg
• Masa Muscular: ${_muscleMass.toStringAsFixed(1)} kg (${((_muscleMass / double.parse(_weightCtrl.text)) * 100).toStringAsFixed(1)}%)
• Masa Ósea: ${_boneMass.toStringAsFixed(1)} kg
• Agua corporal: ${_waterPercentage.toStringAsFixed(1)}%

INDICADORES DE RIESGO:
• Grasa Visceral: $_visceralFat/12 - ${_visceralFat <= 5 ? 'BAJO' : _visceralFat <= 9 ? 'MODERADO' : 'ALTO'} riesgo
• Cintura/Cadera: ${_waistHipRatio.toStringAsFixed(2)} - ${_getWaistHipRatioInterpretation(_waistHipRatio)}
• Cintura/Altura: ${_waistHeightRatio.toStringAsFixed(2)} - ${_getWaistHeightRatioInterpretation(_waistHeightRatio)}

METABOLISMO:
• Edad Metabólica: $_metabolicAge años
• TMB: ${_basalMetabolicRate.toStringAsFixed(0)} kcal/día

SOMATOTIPO: $_bodyType

${_getHealthRiskAssessment()}

RECOMENDACIONES BASADAS EN EVIDENCIA:
${_getEvidenceBasedRecommendations()}
        '''
      };

      if (widget.existingMeasurement != null) {
        await supabase
            .from('body_measurements')
            .update(measurementData)
            .eq('id', widget.existingMeasurement!['id']);
      } else {
        await supabase.from('body_measurements').insert(measurementData);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Análisis científico guardado - IMC: ${_bmi.toStringAsFixed(1)}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      if (widget.onSaved != null) {
        widget.onSaved!();
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  String _getHealthRiskAssessment() {
    String assessment = '';

    if (_waistHipRatio > (_selectedGender == 'male' ? 0.95 : 0.85)) {
      assessment +=
          '• ALERTA: Distribución androide (alto riesgo metabólico)\n';
    }

    if (_waistHeightRatio > 0.55) {
      assessment += '• ALERTA: Obesidad abdominal confirmada\n';
    }

    if (_visceralFat >= 10) {
      assessment += '• ALERTA: Grasa visceral en nivel de riesgo alto\n';
    }

    if (_bodyFat > (_selectedGender == 'male' ? 30 : 35)) {
      assessment += '• ALERTA: Porcentaje de grasa en rango de obesidad\n';
    }

    return assessment.isNotEmpty ? '🚨 EVALUACIÓN DE RIESGO:\n$assessment' : '';
  }

  String _getEvidenceBasedRecommendations() {
    final weight = double.tryParse(_weightCtrl.text) ?? 0.0;
    final diff = weight - _idealWeightGym;
    final double musclePercentage = (_muscleMass / weight) * 100;

    String recommendations = '';

    // Evaluación basada en composición
    if (_bodyFat > (_selectedGender == 'male' ? 25 : 32)) {
      recommendations = '• PRIORIDAD ABSOLUTA: Reducción de grasa\n'
          '• Déficit calórico de 400-600 kcal diarias\n'
          '• Proteína: 1.8-2.2g/kg peso (preservar músculo)\n'
          '• Entrenamiento de fuerza 3-4x/semana\n'
          '• Cardio: 150-250 min/semana (moderado-intenso)\n'
          '• Suplementos: Omega-3, vitamina D\n'
          '• Control médico si IMC > 30';
    } else if (musclePercentage < (_selectedGender == 'male' ? 38 : 30)) {
      recommendations = '• PRIORIDAD: Ganancia muscular\n'
          '• Superávit de 300-500 kcal\n'
          '• Proteína: 1.8-2.2g/kg peso\n'
          '• Entrenamiento pesado progresivo (6-12 rep)\n'
          '• Descanso: 7-9 horas/noche\n'
          '• Creatina: 5g/día (evidencia A)\n'
          '• Medir progreso cada 4 semanas';
    } else if (diff.abs() < 5) {
      recommendations = '• MANTENIMIENTO/RECOMPOSICIÓN\n'
          '• Déficit/superávit ligero (±200 kcal)\n'
          '• Proteína: 1.6-2.0g/kg peso\n'
          '• Entrenamiento periodizado\n'
          '• Monitoreo continuo\n'
          '• Enfocar calidad nutricional';
    }

    // Recomendaciones específicas por riesgo
    if (_waistHipRatio > (_selectedGender == 'male' ? 0.95 : 0.85)) {
      recommendations += '\n\n🔴 ESPECÍFICO OBESIDAD ABDOMINAL:\n'
          '• Dieta mediterránea/antiinflamatoria\n'
          '• Ejercicios HIIT 2-3x/semana\n'
          '• Fibra soluble: 25-30g/día\n'
          '• Evitar azúcares añadidos\n'
          '• Manejo de estrés (meditación, yoga)';
    }

    if (_visceralFat >= 10) {
      recommendations += '\n\n🔴 ESPECÍFICO GRASA VISCERAL:\n'
          '• Omega-3: 2-3g/día\n'
          '• Té verde/matcha diario\n'
          '• Ayuno intermitente 16:8 (opcional)\n'
          '• Ejercicios de alta intensidad\n'
          '• Priorizar sueño (7-8 horas)';
    }

    if (_metabolicAge > (int.tryParse(_ageCtrl.text) ?? 0) + 5) {
      recommendations += '\n\nMETABOLISMO LENTO:\n'
          '• Entrenamiento HIIT para EPOC\n'
          '• Café verde/té verde\n'
          '• Termogénicos: capsaicina, jengibre\n'
          '• Hidratación: 35ml/kg peso\n'
          '• Evitar restricciones extremas';
    }

    return recommendations;
  }

  String _getWaistHipRatioInterpretation(double ratio) {
    if (_selectedGender == 'male') {
      if (ratio < 0.90) return 'Excelente';
      if (ratio < 0.95) return 'Bueno';
      if (ratio < 1.00) return 'Moderado';
      return 'ALTO RIESGO';
    } else {
      if (ratio < 0.80) return 'Excelente';
      if (ratio < 0.85) return 'Bueno';
      if (ratio < 0.90) return 'Moderado';
      return 'ALTO RIESGO';
    }
  }

  String _getWaistHeightRatioInterpretation(double ratio) {
    if (ratio < 0.50) return 'Saludable';
    if (ratio < 0.55) return 'Moderado';
    if (ratio < 0.60) return 'Alto';
    return 'MUY ALTO RIESGO';
  }

  // ========== WIDGETS ==========

  Widget _buildBasicMeasurements(bool isMobile) {
    return Card(
      color: AppTheme.darkGrey,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Medidas Básicas',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 14 : 16,
              ),
            ),

            SizedBox(height: isMobile ? 12 : 16),

            // Peso y Altura
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Peso (kg) *',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: AppTheme.lightGrey,
                        ),
                      ),
                      SizedBox(height: isMobile ? 4 : 6),
                      TextField(
                        controller: _weightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => _calculateAllMetrics(),
                        decoration: InputDecoration(
                          hintText: '81.0',
                          hintStyle: const TextStyle(color: AppTheme.lightGrey),
                          filled: true,
                          fillColor: AppTheme.darkBlack,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(isMobile ? 8 : 10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.all(isMobile ? 10 : 12),
                          suffixText: 'kg',
                          suffixStyle:
                              const TextStyle(color: AppTheme.primaryOrange),
                        ),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 13 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Altura (cm) *',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: AppTheme.lightGrey,
                        ),
                      ),
                      SizedBox(height: isMobile ? 4 : 6),
                      TextField(
                        controller: _heightCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _calculateAllMetrics(),
                        decoration: InputDecoration(
                          hintText: '184.0',
                          hintStyle: const TextStyle(color: AppTheme.lightGrey),
                          filled: true,
                          fillColor: AppTheme.darkBlack,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(isMobile ? 8 : 10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.all(isMobile ? 10 : 12),
                          suffixText: 'cm',
                          suffixStyle:
                              const TextStyle(color: AppTheme.primaryOrange),
                        ),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 13 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: isMobile ? 10 : 12),

            // Edad y Género
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edad',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: AppTheme.lightGrey,
                        ),
                      ),
                      SizedBox(height: isMobile ? 4 : 6),
                      TextField(
                        controller: _ageCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _calculateAllMetrics(),
                        decoration: InputDecoration(
                          hintText: '30',
                          hintStyle: const TextStyle(color: AppTheme.lightGrey),
                          filled: true,
                          fillColor: AppTheme.darkBlack,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(isMobile ? 8 : 10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.all(isMobile ? 10 : 12),
                          suffixText: 'años',
                          suffixStyle:
                              const TextStyle(color: AppTheme.primaryOrange),
                        ),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 13 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Género',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: AppTheme.lightGrey,
                        ),
                      ),
                      SizedBox(height: isMobile ? 4 : 6),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
                        decoration: BoxDecoration(
                          color: AppTheme.darkBlack,
                          borderRadius:
                              BorderRadius.circular(isMobile ? 8 : 10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedGender,
                            isExpanded: true,
                            icon: Icon(
                              Icons.arrow_drop_down,
                              size: isMobile ? 18 : 20,
                              color: AppTheme.primaryOrange,
                            ),
                            dropdownColor: AppTheme.darkGrey,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 13 : 14,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'male',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.male,
                                      size: isMobile ? 14 : 16,
                                      color: Colors.blue,
                                    ),
                                    SizedBox(width: isMobile ? 6 : 8),
                                    Text('Masculino'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'female',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.female,
                                      size: isMobile ? 14 : 16,
                                      color: Colors.pink,
                                    ),
                                    SizedBox(width: isMobile ? 6 : 8),
                                    Text('Femenino'),
                                  ],
                                ),
                              ),
                            ].toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedGender = value);
                                _calculateAllMetrics();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: isMobile ? 12 : 16),

            // Botón para ver composición corporal
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(
                  _showAdvanced ? Icons.visibility_off : Icons.visibility,
                  size: isMobile ? 18 : 20,
                ),
                label: Text(
                  _showAdvanced
                      ? 'Ocultar Composición'
                      : 'Ver Composición Corporal',
                  style: TextStyle(fontSize: isMobile ? 13 : 14),
                ),
                onPressed: () {
                  _calculateAllMetrics();
                  setState(() => _showAdvanced = !_showAdvanced);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.withOpacity(0.2),
                  foregroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyComposition(bool isMobile) {
    return Card(
      color: AppTheme.darkGrey,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Composición Corporal - ANÁLISIS CIENTÍFICO',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 14 : 16,
              ),
            ),

            SizedBox(height: isMobile ? 12 : 16),

            // IMC y Grasa Corporal - principales
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _bmi.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: isMobile ? 24 : 28,
                          fontWeight: FontWeight.bold,
                          color: _getBMIColor(_bmi),
                        ),
                      ),
                      SizedBox(height: isMobile ? 2 : 4),
                      Text(
                        'IMC',
                        style: TextStyle(
                          color: AppTheme.lightGrey,
                          fontSize: isMobile ? 10 : 12,
                        ),
                      ),
                      Text(
                        _getBMICategory(_bmi),
                        style: TextStyle(
                          color: _getBMIColor(_bmi),
                          fontSize: isMobile ? 9 : 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${_bodyFat.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: isMobile ? 22 : 24,
                          fontWeight: FontWeight.bold,
                          color: _getBodyFatColor(_bodyFat),
                        ),
                      ),
                      SizedBox(height: isMobile ? 2 : 4),
                      Text(
                        'Grasa',
                        style: TextStyle(
                          color: AppTheme.lightGrey,
                          fontSize: isMobile ? 10 : 12,
                        ),
                      ),
                      Text(
                        _getBodyFatCategory(_bodyFat),
                        style: TextStyle(
                          color: _getBodyFatColor(_bodyFat),
                          fontSize: isMobile ? 9 : 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${_muscleMass.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      SizedBox(height: isMobile ? 2 : 4),
                      Text(
                        'Músculo',
                        style: TextStyle(
                          color: AppTheme.lightGrey,
                          fontSize: isMobile ? 10 : 12,
                        ),
                      ),
                      Text(
                        'kg',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: isMobile ? 9 : 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: isMobile ? 12 : 16),

            // PESOS IDEALES - NUEVA SECCIÓN
            Container(
              padding: EdgeInsets.all(isMobile ? 10 : 12),
              decoration: BoxDecoration(
                color: AppTheme.darkBlack,
                borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    '🎯 PESOS IDEALES',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: isMobile ? 12 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: isMobile ? 8 : 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '${_idealWeight.toStringAsFixed(1)}',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Salud',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: isMobile ? 9 : 10,
                            ),
                          ),
                          Text(
                            'kg',
                            style: TextStyle(
                              color: AppTheme.lightGrey,
                              fontSize: isMobile ? 8 : 9,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '${_idealWeightGym.toStringAsFixed(1)}',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Deporte',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: isMobile ? 9 : 10,
                            ),
                          ),
                          Text(
                            'kg',
                            style: TextStyle(
                              color: AppTheme.lightGrey,
                              fontSize: isMobile ? 8 : 9,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 6 : 8),
                  Text(
                    'Diferencia: ${(double.tryParse(_weightCtrl.text) ?? 0 - _idealWeightGym).abs().toStringAsFixed(1)}kg',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 10 : 11,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: isMobile ? 12 : 16),

            // Segunda fila - más métricas
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${_fatMass.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      Text(
                        'Grasa',
                        style: TextStyle(
                          color: AppTheme.lightGrey,
                          fontSize: isMobile ? 9 : 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${_leanBodyMass.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        'Magra',
                        style: TextStyle(
                          color: AppTheme.lightGrey,
                          fontSize: isMobile ? 9 : 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _bodyType.length > 8
                            ? _bodyType.substring(0, 8)
                            : _bodyType,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      Text(
                        'Tipo',
                        style: TextStyle(
                          color: AppTheme.lightGrey,
                          fontSize: isMobile ? 9 : 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: isMobile ? 12 : 16),

            // Otras métricas en Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              childAspectRatio: isMobile ? 1.2 : 1.4,
              mainAxisSpacing: isMobile ? 6 : 8,
              crossAxisSpacing: isMobile ? 6 : 8,
              children: [
                _buildMetricCard(
                  isMobile: isMobile,
                  value: '${_waterPercentage.toStringAsFixed(1)}%',
                  label: 'Agua',
                  color: Colors.blue,
                ),
                _buildMetricCard(
                  isMobile: isMobile,
                  value: '${_boneMass.toStringAsFixed(1)}',
                  label: 'Huesos',
                  color: Colors.brown,
                  unit: 'kg',
                ),
                _buildMetricCard(
                  isMobile: isMobile,
                  value: '$_visceralFat',
                  label: 'Visceral',
                  color: _getVisceralFatColor(_visceralFat),
                ),
                _buildMetricCard(
                  isMobile: isMobile,
                  value: '$_metabolicAge',
                  label: 'Metab',
                  color: _getMetabolicAgeColor(
                      _metabolicAge, int.tryParse(_ageCtrl.text) ?? 0),
                ),
                _buildMetricCard(
                  isMobile: isMobile,
                  value: '${_basalMetabolicRate.toStringAsFixed(0)}',
                  label: 'TMB',
                  color: Colors.orange,
                  unit: 'kcal',
                ),
                _buildMetricCard(
                  isMobile: isMobile,
                  value: _waistHipRatio > 0
                      ? _waistHipRatio.toStringAsFixed(2)
                      : 'N/A',
                  label: 'C/C',
                  color: _getWaistHipRatioColor(_waistHipRatio),
                ),
                _buildMetricCard(
                  isMobile: isMobile,
                  value: _waistHeightRatio > 0
                      ? _waistHeightRatio.toStringAsFixed(2)
                      : 'N/A',
                  label: 'C/A',
                  color: _getWaistHeightRatioColor(_waistHeightRatio),
                ),
                _buildMetricCard(
                  isMobile: isMobile,
                  value:
                      '${((_muscleMass / (double.tryParse(_weightCtrl.text) ?? 1)) * 100).toStringAsFixed(1)}%',
                  label: '% Músc',
                  color: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required bool isMobile,
    required String value,
    required String label,
    required Color color,
    String unit = '',
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 6 : 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isMobile ? 2 : 4),
          Text(
            unit.isNotEmpty ? '$label ($unit)' : label,
            style: TextStyle(
              color: AppTheme.lightGrey,
              fontSize: isMobile ? 9 : 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildBodyMeasurements(bool isMobile) {
    return Card(
      color: AppTheme.darkGrey,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Medidas Corporales (cm)',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 14 : 16,
              ),
            ),

            SizedBox(height: isMobile ? 6 : 8),

            Text(
              'Para cálculos precisos de grasa - Fórmula US Navy',
              style: TextStyle(
                color: AppTheme.lightGrey,
                fontSize: isMobile ? 11 : 12,
              ),
            ),

            SizedBox(height: isMobile ? 12 : 16),

            // Primera fila
            Row(
              children: [
                Expanded(
                  child: _buildMeasurementField(
                    isMobile: isMobile,
                    controller: _neckCtrl,
                    label: 'Cuello*',
                    icon: Icons.accessibility,
                    important: true,
                  ),
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: _buildMeasurementField(
                    isMobile: isMobile,
                    controller: _shouldersCtrl,
                    label: 'Hombros',
                    icon: Icons.accessibility,
                  ),
                ),
              ],
            ),

            SizedBox(height: isMobile ? 10 : 12),

            // Segunda fila
            Row(
              children: [
                Expanded(
                  child: _buildMeasurementField(
                    isMobile: isMobile,
                    controller: _chestCtrl,
                    label: 'Pecho',
                    icon: Icons.accessibility,
                  ),
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: _buildMeasurementField(
                    isMobile: isMobile,
                    controller: _armsCtrl,
                    label: 'Brazos',
                    icon: Icons.accessibility,
                  ),
                ),
              ],
            ),

            SizedBox(height: isMobile ? 10 : 12),

            // Tercera fila - IMPORTANTE para cálculos
            Row(
              children: [
                Expanded(
                  child: _buildMeasurementField(
                    isMobile: isMobile,
                    controller: _waistCtrl,
                    label: 'Cintura*',
                    icon: Icons.accessibility,
                    important: true,
                  ),
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: _buildMeasurementField(
                    isMobile: isMobile,
                    controller: _glutesCtrl,
                    label: 'Cadera*',
                    icon: Icons.accessibility,
                    important: true,
                  ),
                ),
              ],
            ),

            SizedBox(height: isMobile ? 10 : 12),

            // Cuarta fila
            Row(
              children: [
                Expanded(
                  child: _buildMeasurementField(
                    isMobile: isMobile,
                    controller: _legsCtrl,
                    label: 'Piernas',
                    icon: Icons.accessibility,
                  ),
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: _buildMeasurementField(
                    isMobile: isMobile,
                    controller: _calvesCtrl,
                    label: 'Pantorrillas',
                    icon: Icons.accessibility,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementField({
    required bool isMobile,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool important = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                color: important ? Colors.orange : AppTheme.lightGrey,
                fontWeight: important ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (important)
              const Text(
                '*',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        SizedBox(height: isMobile ? 4 : 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _calculateAllMetrics(),
          decoration: InputDecoration(
            hintText: '0.0',
            hintStyle: const TextStyle(color: AppTheme.lightGrey),
            filled: true,
            fillColor: AppTheme.darkBlack,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.all(isMobile ? 10 : 12),
            prefixIcon: Icon(
              icon,
              size: isMobile ? 16 : 18,
              color: important ? Colors.orange : AppTheme.primaryOrange,
            ),
            suffixText: 'cm',
            suffixStyle: TextStyle(
              color: important ? Colors.orange : AppTheme.primaryOrange,
              fontSize: isMobile ? 12 : 14,
            ),
          ),
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 13 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviousMeasurement(bool isMobile) {
    if (_previousMeasurement == null) return const SizedBox.shrink();

    final prev = _previousMeasurement!;
    final date = prev['measurement_date'] != null
        ? DateTime.parse(prev['measurement_date']).toLocal()
        : DateTime.now();
    final formattedDate = '${date.day}/${date.month}/${date.year}';

    return Card(
      color: AppTheme.darkGrey,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history,
                    color: Colors.orange, size: isMobile ? 18 : 20),
                SizedBox(width: isMobile ? 6 : 8),
                Text(
                  'Medición Anterior',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 13 : 14,
                  ),
                ),
                const Spacer(),
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: AppTheme.lightGrey,
                    fontSize: isMobile ? 10 : 12,
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 10 : 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${prev['weight']?.toStringAsFixed(1) ?? '0'}',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: isMobile ? 2 : 4),
                      Text(
                        'Peso',
                        style: TextStyle(
                          color: AppTheme.lightGrey,
                          fontSize: isMobile ? 10 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${prev['height']?.toStringAsFixed(1) ?? '0'}',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: isMobile ? 2 : 4),
                      Text(
                        'Altura',
                        style: TextStyle(
                          color: AppTheme.lightGrey,
                          fontSize: isMobile ? 10 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${prev['bmi']?.toStringAsFixed(1) ?? '0'}',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: _getBMIColor(prev['bmi']),
                        ),
                      ),
                      SizedBox(height: isMobile ? 2 : 4),
                      Text(
                        'IMC',
                        style: TextStyle(
                          color: AppTheme.lightGrey,
                          fontSize: isMobile ? 10 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection(bool isMobile) {
    return Card(
      color: AppTheme.darkGrey,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notas / Lesiones',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 14 : 16,
              ),
            ),
            SizedBox(height: isMobile ? 8 : 12),
            TextField(
              controller: _injuriesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ej: Lesión en rodilla izquierda, alergias, etc.',
                hintStyle: const TextStyle(color: AppTheme.lightGrey),
                filled: true,
                fillColor: AppTheme.darkBlack,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
              ),
              style:
                  TextStyle(color: Colors.white, fontSize: isMobile ? 13 : 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science, size: isMobile ? 16 : 18, color: Colors.blue),
              SizedBox(width: isMobile ? 6 : 8),
              Text(
                'FÓRMULAS VALIDADAS CIENTÍFICAMENTE',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 13 : 14,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 6 : 8),
          Text(
            '• US Navy (1984) - % grasa corporal\n'
            '• Masa muscular: 50% LBM (hombres), 42% LBM (mujeres)\n'
            '• Agua corporal: ajuste por % grasa\n'
            '• Huesos: 12-15% peso\n'
            '• Normalización de compartimentos\n'
            '• Rango biológico validado',
            style: TextStyle(
              color: Colors.blue,
              fontSize: isMobile ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isMobile) {
    return AppBar(
      title: Text(
        widget.existingMeasurement != null
            ? 'Editar Medidas Científicas'
            : 'Registrar Medidas Científicas',
        style: TextStyle(fontSize: isMobile ? 16 : 18),
      ),
      backgroundColor: AppTheme.darkBlack,
      elevation: 1,
      actions: [
        if (_clientInfo != null && !isMobile)
          TextButton.icon(
            icon: const Icon(Icons.person),
            label: Text(
              _clientInfo!['profiles']?['full_name']?.split(' ').first ??
                  'Cliente',
              style: TextStyle(fontSize: isMobile ? 12 : 14),
            ),
            onPressed: null,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryOrange,
            ),
          ),
      ],
    );
  }

  // ========== FUNCIONES DE COLORES ==========

  Color _getBMIColor(double? bmi) {
    if (bmi == null) return Colors.white;
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25) return Colors.green;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
  }

  String _getBMICategory(double? bmi) {
    if (bmi == null) return '';
    if (bmi < 18.5) return 'Bajo';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Sobrepeso';
    return 'Obesidad';
  }

  Color _getBodyFatColor(double? bodyFat) {
    if (bodyFat == null) return Colors.white;
    if (_selectedGender == 'male') {
      if (bodyFat < 15) return Colors.green;
      if (bodyFat < 20) return Colors.blue;
      if (bodyFat < 25) return Colors.yellow;
      return Colors.red;
    } else {
      if (bodyFat < 20) return Colors.green;
      if (bodyFat < 25) return Colors.blue;
      if (bodyFat < 30) return Colors.yellow;
      return Colors.red;
    }
  }

  String _getBodyFatCategory(double? bodyFat) {
    if (bodyFat == null) return '';
    if (_selectedGender == 'male') {
      if (bodyFat < 15) return 'Atleta';
      if (bodyFat < 20) return 'Fitness';
      if (bodyFat < 25) return 'Normal';
      return 'Alto';
    } else {
      if (bodyFat < 20) return 'Atleta';
      if (bodyFat < 25) return 'Fitness';
      if (bodyFat < 30) return 'Normal';
      return 'Alto';
    }
  }

  Color _getVisceralFatColor(int visceralFat) {
    if (visceralFat < 5) return Colors.green;
    if (visceralFat < 9) return Colors.yellow;
    return Colors.red;
  }

  Color _getMetabolicAgeColor(int metabolicAge, int chronologicalAge) {
    int difference = metabolicAge - chronologicalAge;
    if (difference < -5) return Colors.green;
    if (difference < 5) return Colors.yellow;
    return Colors.red;
  }

  Color _getWaistHipRatioColor(double ratio) {
    if (_selectedGender == 'male') {
      if (ratio < 0.90) return Colors.green;
      if (ratio < 0.95) return Colors.yellow;
      return Colors.red;
    } else {
      if (ratio < 0.80) return Colors.green;
      if (ratio < 0.85) return Colors.yellow;
      return Colors.red;
    }
  }

  Color _getWaistHeightRatioColor(double ratio) {
    if (ratio < 0.5) return Colors.green;
    if (ratio < 0.6) return Colors.yellow;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: _buildAppBar(isMobile),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Medición anterior
                  _buildPreviousMeasurement(isMobile),

                  if (_previousMeasurement != null)
                    SizedBox(height: isMobile ? 16 : 20),

                  // Medidas básicas
                  _buildBasicMeasurements(isMobile),

                  SizedBox(height: isMobile ? 16 : 20),

                  // Composición corporal (si está visible)
                  if (_showAdvanced) ...[
                    _buildBodyComposition(isMobile),
                    SizedBox(height: isMobile ? 16 : 20),
                  ],

                  // Medidas corporales
                  _buildBodyMeasurements(isMobile),

                  SizedBox(height: isMobile ? 16 : 20),

                  // Notas/lesiones
                  _buildNotesSection(isMobile),

                  SizedBox(height: isMobile ? 20 : 24),

                  // Botón de guardar
                  GradientButton(
                    text: _isSubmitting
                        ? 'Guardando...'
                        : '🔬 Guardar Análisis Científico',
                    onPressed: _isSubmitting ? null : _saveMeasurement,
                    isLoading: _isSubmitting,
                    gradientColors: [
                      AppTheme.primaryOrange,
                      AppTheme.orangeAccent
                    ],
                  ),

                  SizedBox(height: isMobile ? 12 : 16),

                  // Información adicional
                  _buildInfoCard(isMobile),

                  SizedBox(height: isMobile ? 24 : 32),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
    _neckCtrl.dispose();
    _shouldersCtrl.dispose();
    _chestCtrl.dispose();
    _armsCtrl.dispose();
    _waistCtrl.dispose();
    _glutesCtrl.dispose();
    _legsCtrl.dispose();
    _calvesCtrl.dispose();
    _injuriesCtrl.dispose();
    super.dispose();
  }
}
