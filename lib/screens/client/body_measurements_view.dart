import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';

class ClientBodyMeasurementsScreen extends StatefulWidget {
  const ClientBodyMeasurementsScreen({super.key});

  @override
  State<ClientBodyMeasurementsScreen> createState() =>
      _ClientBodyMeasurementsScreenState();
}

class _ClientBodyMeasurementsScreenState
    extends State<ClientBodyMeasurementsScreen> {
  List<Map<String, dynamic>> _measurements = [];
  Map<String, dynamic>? _clientData;
  bool _isLoading = true;
  int? _selectedMeasurementIndex;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) throw Exception('No autenticado');

      final clientRes = await supabase
          .from('clients')
          .select('id')
          .eq('user_id', uid)
          .maybeSingle();

      if (clientRes != null) {
        final measuresRes = await supabase
            .from('body_measurements')
            .select('*')
            .eq('client_id', clientRes['id'])
            .order('measurement_date', ascending: false);

        setState(() {
          _clientData = clientRes;
          _measurements = List.from(measuresRes);
          if (_measurements.isNotEmpty) {
            _selectedMeasurementIndex = 0;
          }
        });
      }
    } catch (e) {
      debugPrint('Error cargando medidas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar medidas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ========== FUNCIONES DE ANÁLISIS INTELIGENTES ==========

  String _getBMIAnalysis(
      double bmi, double weight, double height, String gender) {
    final idealWeightMedical = _calculateMedicalIdealWeight(height, gender);
    final idealWeightGym = _calculateGymIdealWeight(height, gender);
    final diff = weight - idealWeightMedical;

    if (bmi < 18.5) {
      return 'IMC ${bmi.toStringAsFixed(1)} - BAJO PESO\n'
          '• Según tu altura (${height}cm):\n'
          '  - Peso ideal salud: ${idealWeightMedical.toStringAsFixed(1)}kg\n'
          '  - Diferencia: -${(idealWeightMedical - weight).abs().toStringAsFixed(1)}kg\n'
          '• Perfecto para ganar masa muscular';
    } else if (bmi < 25) {
      return 'IMC ${bmi.toStringAsFixed(1)} - NORMAL\n'
          '• Para tu altura (${height}cm):\n'
          '  - Ideal salud: ${idealWeightMedical.toStringAsFixed(1)}kg\n'
          '  - Ideal gym: ${idealWeightGym.toStringAsFixed(1)}kg\n'
          '• Tu peso actual está en rango óptimo';
    } else if (bmi < 30) {
      return 'IMC ${bmi.toStringAsFixed(1)} - SOBREPESO\n'
          '• Según tu altura (${height}cm):\n'
          '  - Peso ideal: ${idealWeightMedical.toStringAsFixed(1)}kg\n'
          '  - Diferencia: +${diff.toStringAsFixed(1)}kg\n'
          '• Evalúa si es músculo (positivo) o grasa';
    } else {
      return 'IMC ${bmi.toStringAsFixed(1)} - OBESIDAD\n'
          '• Para tu altura (${height}cm):\n'
          '  - Peso recomendado: ${idealWeightMedical.toStringAsFixed(1)}kg\n'
          '  - Diferencia: +${diff.toStringAsFixed(1)}kg\n'
          '• Enfócate en reducción controlada';
    }
  }

  String _getWeightAnalysis(double weight, double height, String gender) {
    final medicalIdeal = _calculateMedicalIdealWeight(height, gender);
    final gymIdeal = _calculateGymIdealWeight(height, gender);
    final diffMedical = weight - medicalIdeal;
    final diffGym = weight - gymIdeal;

    return 'Tu peso: ${weight}kg\n'
        '• Altura: ${height}cm\n'
        '• Ideal salud: ${medicalIdeal.toStringAsFixed(1)}kg\n'
        '• Ideal gym: ${gymIdeal.toStringAsFixed(1)}kg\n'
        '• Diferencia: ${diffMedical.toStringAsFixed(1)}kg vs salud\n'
        '• Diferencia: ${diffGym.toStringAsFixed(1)}kg vs gym';
  }

  String _getBodyFatAnalysis(double bodyFat, String gender, double weight,
      double waist, double height) {
    final fatMass = (weight * bodyFat / 100).toStringAsFixed(1);
    final waistHeightRatio = waist / height;

    if (gender == 'male') {
      if (bodyFat < 10) {
        return '${bodyFat.toStringAsFixed(1)}% - CULTURISTA\n'
            '• ${fatMass}kg de grasa\n'
            '• Muy definido, abdominales visibles\n'
            '• Nivel avanzado/competición';
      } else if (bodyFat < 15) {
        return '${bodyFat.toStringAsFixed(1)}% - ATLÉTICO\n'
            '• ${fatMass}kg de grasa\n'
            '• Buena definición muscular\n'
            '• Ideal para ganar músculo limpio';
      } else if (bodyFat < 20) {
        return '${bodyFat.toStringAsFixed(1)}% - FITNESS\n'
            '• ${fatMass}kg de grasa\n'
            '• Músculos visibles\n'
            '• Buen punto para progresar';
      } else if (bodyFat < 25) {
        return '${bodyFat.toStringAsFixed(1)}% - PROMEDIO\n'
            '• ${fatMass}kg de grasa\n'
            '• Rango común en hombres\n'
            '• Objetivo: bajar a 15-18%';
      } else {
        return '${bodyFat.toStringAsFixed(1)}% - ELEVADO\n'
            '• ${fatMass}kg de grasa\n'
            '• Prioridad: pérdida de grasa\n'
            '• Relación cintura/altura: ${waistHeightRatio.toStringAsFixed(2)}';
      }
    } else {
      if (bodyFat < 20) {
        return '${bodyFat.toStringAsFixed(1)}% - ATLETA MUJER\n'
            '• ${fatMass}kg de grasa\n'
            '• Muy bajo (para mujeres)\n'
            '• Cuidado con mantenerlo';
      } else if (bodyFat < 25) {
        return '${bodyFat.toStringAsFixed(1)}% - FITNESS\n'
            '• ${fatMass}kg de grasa\n'
            '• Tonificación visible\n'
            '• Ideal para mujeres que entrenan';
      } else if (bodyFat < 30) {
        return '${bodyFat.toStringAsFixed(1)}% - SALUDABLE\n'
            '• ${fatMass}kg de grasa\n'
            '• Rango normal para mujeres\n'
            '• Buen punto de partida';
      } else {
        return '${bodyFat.toStringAsFixed(1)}% - ELEVADO\n'
            '• ${fatMass}kg de grasa\n'
            '• Enfócate en tonificación\n'
            '• Relación cintura/altura: ${waistHeightRatio.toStringAsFixed(2)}';
      }
    }
  }

  String _getMuscleAnalysis(
      double muscleMass, double weight, String gender, double height) {
    final musclePercentage = (muscleMass / weight * 100).toStringAsFixed(1);
    final expected = gender == 'male' ? weight * 0.4 : weight * 0.33;
    final diff = muscleMass - expected;

    if (gender == 'male') {
      if (muscleMass > weight * 0.45) {
        return '${muscleMass.toStringAsFixed(1)}kg (${musclePercentage}%) - AVANZADO\n'
            '• Excelente masa muscular\n'
            '• Por encima del promedio\n'
            '• +${diff.toStringAsFixed(1)}kg sobre esperado';
      } else if (muscleMass > weight * 0.40) {
        return '${muscleMass.toStringAsFixed(1)}kg (${musclePercentage}%) - INTERMEDIO\n'
            '• Buena masa muscular\n'
            '• Desarrollo consistente\n'
            '• Sigue ganando fuerza';
      } else if (muscleMass > weight * 0.35) {
        return '${muscleMass.toStringAsFixed(1)}kg (${musclePercentage}%) - PRINCIPIANTE+\n'
            '• Base sólida\n'
            '• Puedes ganar más\n'
            '• Proteína + entrenamiento';
      } else {
        return '${muscleMass.toStringAsFixed(1)}kg (${musclePercentage}%) - PRINCIPIANTE\n'
            '• Oportunidad de crecimiento\n'
            '• Enfócate en progresión\n'
            '• -${diff.abs().toStringAsFixed(1)}kg bajo esperado';
      }
    } else {
      if (muscleMass > weight * 0.40) {
        return '${muscleMass.toStringAsFixed(1)}kg (${musclePercentage}%) - AVANZADA\n'
            '• Excelente para mujer\n'
            '• Mucho trabajo y constancia';
      } else if (muscleMass > weight * 0.35) {
        return '${muscleMass.toStringAsFixed(1)}kg (${musclePercentage}%) - INTERMEDIA\n'
            '• Buena masa muscular\n'
            '• Tonificación visible';
      } else {
        return '${muscleMass.toStringAsFixed(1)}kg (${musclePercentage}%) - BUENA BASE\n'
            '• Puedes seguir desarrollando\n'
            '• Entrenamiento de fuerza';
      }
    }
  }

  String _getProgressAnalysis(int currentIndex) {
    if (_measurements.length < 2) return 'Primera medición registrada';

    final current = _measurements[currentIndex];
    final previous = _measurements.length > currentIndex + 1
        ? _measurements[currentIndex + 1]
        : null;

    if (previous == null) return 'Comparando con inicio';

    double weightChange = (current['weight'] ?? 0) - (previous['weight'] ?? 0);
    double fatChange = (current['body_fat'] ?? 0) - (previous['body_fat'] ?? 0);
    double muscleChange =
        (current['muscle_mass'] ?? 0) - (previous['muscle_mass'] ?? 0);

    if (weightChange > 0.5 && fatChange < -0.3 && muscleChange > 0.3) {
      return 'PROGRESO IDEAL\n\nGanaste músculo Y perdiste grasa. Excelente balance en tu composición corporal. Continúa manteniendo este ritmo de entrenamiento y nutrición.';
    } else if (weightChange > 1 && muscleChange > 0.5) {
      return 'BUENA GANANCIA\n\nMás músculo con aumento de peso. Tu fase de bulking es correcta. Sigue aumentando carga en entrenamientos.';
    } else if (weightChange < -1 && fatChange < -1 && muscleChange > 0) {
      return 'EXCELENTE DEFINICIÓN\n\nQuemaste grasa manteniendo músculo. Tu fase de corte es muy exitosa. Excelente trabajo.';
    } else if (weightChange > 2 && fatChange > 1 && muscleChange > 0) {
      return 'BULKING EN PROGRESO\n\nGanancia de peso con grasa notable. Considera ajustar tu alimentación y aumentar actividad cardio.';
    } else if (weightChange < -1 && fatChange < 0 && muscleChange < -0.5) {
      return 'PÉRDIDA DE MÚSCULO\n\nBajó peso pero perdió masa muscular. Aumenta ingesta de proteína e intensidad de entrenamientos.';
    } else if (weightChange.abs() < 1 && fatChange < -0.5 && muscleChange > 0) {
      return 'RECOMPOSICIÓN CORPORAL\n\nMismo peso, pero mejor composición. Excelente, estás mejorando tu figura sin cambios drásticos.';
    } else {
      return 'ESTABILIDAD\n\nPocos cambios detectados. Analiza tu rutina de entrenamiento y nutrición. Considera nuevas estrategias.';
    }
  }

  double _calculateGymIdealWeight(double height, String gender) {
    double targetBMI = gender == 'male' ? 24.5 : 23.5;
    double heightM = height / 100;
    return targetBMI * heightM * heightM;
  }

  double _calculateMedicalIdealWeight(double height, String gender) {
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

  // ========== FUNCIONES RESPONSIVAS ==========

  bool get _isSmallPhone => MediaQuery.of(context).size.width < 360;
  bool get _isMediumPhone => MediaQuery.of(context).size.width < 400;
  bool get _isLargePhone => MediaQuery.of(context).size.width >= 400;

  double _getFontSize(double small, double medium, double large) {
    if (_isSmallPhone) return small;
    if (_isMediumPhone) return medium;
    return large;
  }

  EdgeInsets _getPadding(double small, double medium, double large) {
    double padding = _isSmallPhone ? small : (_isMediumPhone ? medium : large);
    return EdgeInsets.all(padding);
  }

  double _getIconSize(double small, double medium, double large) {
    if (_isSmallPhone) return small;
    if (_isMediumPhone) return medium;
    return large;
  }

  // ========== WIDGETS PARA MEDIDAS CORPORALES ==========

  Widget _buildBodyMeasurementsSection(Map<String, dynamic> measurement) {
    final neck = measurement['neck']?.toString() ?? 'N/A';
    final shoulders = measurement['shoulders']?.toString() ?? 'N/A';
    final chest = measurement['chest']?.toString() ?? 'N/A';
    final arms = measurement['arms']?.toString() ?? 'N/A';
    final waist = measurement['waist']?.toString() ?? 'N/A';
    final glutes = measurement['glutes']?.toString() ?? 'N/A';
    final legs = measurement['legs']?.toString() ?? 'N/A';
    final calves = measurement['calves']?.toString() ?? 'N/A';
    final injuries = measurement['injuries']?.toString() ?? 'Ninguna';

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: _isSmallPhone ? 12 : 16,
        vertical: _isSmallPhone ? 8 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MEDIDAS CORPORALES',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: _getFontSize(13, 14, 15),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: _isSmallPhone ? 12 : 16),

          // Grid de medidas corporales
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio:
                _isSmallPhone ? 1.4 : (_isMediumPhone ? 1.5 : 1.6),
            mainAxisSpacing: _isSmallPhone ? 8 : 10,
            crossAxisSpacing: _isSmallPhone ? 8 : 10,
            children: [
              _buildMeasurementItem('Cuello', '$neck cm', Colors.blue),
              _buildMeasurementItem('Hombros', '$shoulders cm', Colors.blue),
              _buildMeasurementItem('Pecho', '$chest cm', Colors.red),
              _buildMeasurementItem('Brazos', '$arms cm', Colors.orange),
              _buildMeasurementItem('Cintura', '$waist cm', Colors.green),
              _buildMeasurementItem('Glúteos', '$glutes cm', Colors.purple),
              _buildMeasurementItem('Piernas', '$legs cm', Colors.teal),
              _buildMeasurementItem('Pantorrillas', '$calves cm', Colors.brown),
            ],
          ),

          // Lesiones/Comentarios
          if (injuries.isNotEmpty && injuries != 'Ninguna') ...[
            SizedBox(height: _isSmallPhone ? 16 : 20),
            Container(
              padding: EdgeInsets.all(_isSmallPhone ? 12 : 14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(_isSmallPhone ? 10 : 12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.medical_services,
                        color: Colors.red,
                        size: _getIconSize(16, 17, 18),
                      ),
                      SizedBox(width: _isSmallPhone ? 6 : 8),
                      Text(
                        'NOTAS IMPORTANTES',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w800,
                          fontSize: _getFontSize(12, 13, 14),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: _isSmallPhone ? 6 : 8),
                  Text(
                    injuries,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _getFontSize(11, 12, 13),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMeasurementItem(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(_isSmallPhone ? 10 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(_isSmallPhone ? 8 : 10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: _getFontSize(11, 12, 13),
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: _isSmallPhone ? 4 : 6),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: _getFontSize(14, 15, 16),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ========== WIDGETS RESPONSIVOS ==========

  Widget _buildMeasurementSelector() {
    if (_measurements.length <= 1) return const SizedBox();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isSmallPhone ? 12 : 16,
        vertical: _isSmallPhone ? 8 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isSmallPhone ? 'HISTORIAL' : 'HISTORIAL DE MEDICIONES',
            style: TextStyle(
              color: Colors.white,
              fontSize: _getFontSize(12, 14, 14),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: _isSmallPhone ? 6 : 8),
          SizedBox(
            height: _isSmallPhone ? 40 : 45,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _measurements.length,
              itemBuilder: (context, index) {
                final measurement = _measurements[index];
                final date = DateFormat('dd/MM').format(
                  DateTime.parse(measurement['measurement_date']).toLocal(),
                );
                final isSelected = _selectedMeasurementIndex == index;

                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedMeasurementIndex = index),
                  child: Container(
                    margin: EdgeInsets.only(right: _isSmallPhone ? 6 : 8),
                    padding: EdgeInsets.symmetric(
                      horizontal: _isSmallPhone ? 12 : 16,
                      vertical: _isSmallPhone ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryOrange
                          : AppTheme.darkBlack.withOpacity(0.7),
                      borderRadius:
                          BorderRadius.circular(_isSmallPhone ? 8 : 10),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryOrange
                            : Colors.grey.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          date,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[400],
                            fontWeight: FontWeight.w600,
                            fontSize: _getFontSize(11, 13, 13),
                          ),
                        ),
                        if (isSelected && !_isSmallPhone)
                          Icon(
                            Icons.check_circle,
                            size: 12,
                            color: Colors.white,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressReport() {
    if (_selectedMeasurementIndex == null || _measurements.length < 2) {
      return const SizedBox();
    }

    final current = _measurements[_selectedMeasurementIndex!];
    final previous = _measurements[_selectedMeasurementIndex! + 1];
    final currentDate = DateFormat('dd/MM').format(
      DateTime.parse(current['measurement_date']).toLocal(),
    );
    final previousDate = DateFormat('dd/MM').format(
      DateTime.parse(previous['measurement_date']).toLocal(),
    );

    double weightChange = (current['weight'] ?? 0) - (previous['weight'] ?? 0);
    double fatChange = (current['body_fat'] ?? 0) - (previous['body_fat'] ?? 0);
    double muscleChange =
        (current['muscle_mass'] ?? 0) - (previous['muscle_mass'] ?? 0);

    Color weightColor = weightChange >= 0 ? Colors.green : Colors.red;
    Color fatColor = fatChange <= 0 ? Colors.green : Colors.red;
    Color muscleColor = muscleChange >= 0 ? Colors.green : Colors.red;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: _isSmallPhone ? 12 : 16,
        vertical: _isSmallPhone ? 6 : 8,
      ),
      padding: _getPadding(12, 14, 16),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(_isSmallPhone ? 14 : 16),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(_isSmallPhone ? 6 : 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.trending_up,
                  color: Colors.green,
                  size: _getIconSize(18, 20, 24),
                ),
              ),
              SizedBox(width: _isSmallPhone ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSmallPhone
                          ? 'PROGRESO $previousDate → $currentDate'
                          : 'ANÁLISIS DE PROGRESO $previousDate → $currentDate',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: _getFontSize(13, 14, 16),
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: _isSmallPhone ? 2 : 4),
                    Text(
                      _getProgressAnalysis(_selectedMeasurementIndex!),
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: _getFontSize(10, 11, 12),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: _isSmallPhone ? 12 : 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildChangeItem(
                label: 'PESO',
                value:
                    '${weightChange > 0 ? '+' : ''}${weightChange.toStringAsFixed(1)}kg',
                color: weightColor,
                icon: weightChange > 0
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                analysis: weightChange > 0 ? 'Subió' : 'Bajó',
              ),
              _buildChangeItem(
                label: 'GRASA',
                value:
                    '${fatChange > 0 ? '+' : ''}${fatChange.toStringAsFixed(1)}%',
                color: fatColor,
                icon: fatChange < 0 ? Icons.arrow_downward : Icons.arrow_upward,
                analysis: fatChange < 0 ? 'Menos' : 'Más',
              ),
              _buildChangeItem(
                label: 'MÚSCULO',
                value:
                    '${muscleChange > 0 ? '+' : ''}${muscleChange.toStringAsFixed(1)}kg',
                color: muscleColor,
                icon: muscleChange > 0
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                analysis: muscleChange > 0 ? 'Más' : 'Menos',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChangeItem({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    required String analysis,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(_isSmallPhone ? 6 : 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(0.5),
              width: _isSmallPhone ? 1.5 : 2,
            ),
          ),
          child: Icon(
            icon,
            size: _getIconSize(16, 18, 20),
            color: color,
          ),
        ),
        SizedBox(height: _isSmallPhone ? 4 : 6),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: _getFontSize(14, 15, 16),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: _isSmallPhone ? 2 : 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey,
            fontSize: _getFontSize(9, 10, 11),
            fontWeight: FontWeight.w600,
          ),
        ),
        if (!_isSmallPhone)
          Text(
            analysis,
            style: TextStyle(
              color: color,
              fontSize: 10,
            ),
          ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required String analysis,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: () => _showAnalysisDialog(title, value, analysis, color),
      child: Container(
        padding: EdgeInsets.all(_isSmallPhone ? 10 : 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(_isSmallPhone ? 10 : 12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(_isSmallPhone ? 4 : 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(_isSmallPhone ? 6 : 8),
                  ),
                  child: Icon(
                    icon,
                    size: _getIconSize(14, 15, 16),
                    color: color,
                  ),
                ),
                SizedBox(width: _isSmallPhone ? 6 : 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: _getFontSize(11, 12, 13),
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.info_outline,
                  size: _getIconSize(12, 13, 14),
                  color: color.withOpacity(0.7),
                ),
              ],
            ),
            SizedBox(height: _isSmallPhone ? 8 : 10),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: _getFontSize(18, 19, 20),
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: _isSmallPhone ? 2 : 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey,
                fontSize: _getFontSize(10, 11, 11),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showAnalysisDialog(
      String title, String value, String analysis, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: _isSmallPhone ? 0.6 : 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: EdgeInsets.all(_isSmallPhone ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.only(bottom: _isSmallPhone ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(_isSmallPhone ? 8 : 10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.analytics,
                        color: color,
                        size: _getIconSize(22, 24, 26),
                      ),
                    ),
                    SizedBox(width: _isSmallPhone ? 10 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: color,
                              fontSize: _getFontSize(16, 17, 18),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            value,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _getFontSize(16, 17, 18),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: _isSmallPhone ? 16 : 20),
                Container(
                  padding: EdgeInsets.all(_isSmallPhone ? 14 : 16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBlack,
                    borderRadius:
                        BorderRadius.circular(_isSmallPhone ? 12 : 14),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ANÁLISIS DETALLADO',
                        style: TextStyle(
                          color: color,
                          fontSize: _getFontSize(14, 15, 16),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: _isSmallPhone ? 8 : 10),
                      Text(
                        analysis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: _getFontSize(13, 14, 14),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: _isSmallPhone ? 16 : 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      padding: EdgeInsets.symmetric(
                          vertical: _isSmallPhone ? 14 : 16),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(_isSmallPhone ? 10 : 12),
                      ),
                    ),
                    child: Text(
                      'ENTENDIDO',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: _getFontSize(14, 15, 16),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: _isSmallPhone ? 10 : 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeasurementCard(Map<String, dynamic> measurement) {
    final date = DateFormat('dd/MM/yyyy').format(
      DateTime.parse(measurement['measurement_date']).toLocal(),
    );
    final gender = measurement['gender'] ?? 'male';
    final height = measurement['height']?.toDouble() ?? 0;
    final weight = measurement['weight']?.toDouble() ?? 0;
    final bmi = measurement['bmi']?.toDouble() ?? 0;
    final waist = measurement['waist']?.toDouble() ?? 0;

    return Column(
      children: [
        Container(
          margin: EdgeInsets.symmetric(
            horizontal: _isSmallPhone ? 12 : 16,
            vertical: _isSmallPhone ? 6 : 8,
          ),
          padding: EdgeInsets.all(_isSmallPhone ? 14 : 16),
          decoration: BoxDecoration(
            color: AppTheme.darkGrey,
            borderRadius: BorderRadius.circular(_isSmallPhone ? 14 : 16),
            border: Border.all(color: Colors.grey[800]!, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isSmallPhone ? ' $date' : ' MEDICIÓN DEL $date',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: _getFontSize(14, 15, 16),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: _isSmallPhone ? 2 : 4),
                        Text(
                          '${measurement['age'] ?? '?'} años • ${gender == 'male' ? '👨' : '👩'}',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: _getFontSize(10, 11, 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: _isSmallPhone ? 6 : 8),
                  // IMC
                  GestureDetector(
                    onTap: () => _showAnalysisDialog(
                      'ÍNDICE DE MASA CORPORAL',
                      '${bmi.toStringAsFixed(1)}',
                      _getBMIAnalysis(bmi, weight, height, gender),
                      _getBMIColor(bmi),
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: _isSmallPhone ? 10 : 12,
                        vertical: _isSmallPhone ? 6 : 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getBMIColor(bmi),
                            _getBMIColor(bmi).withOpacity(0.7),
                          ],
                        ),
                        borderRadius:
                            BorderRadius.circular(_isSmallPhone ? 8 : 10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'IMC',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _getFontSize(9, 10, 10),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            bmi.toStringAsFixed(1),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _getFontSize(18, 19, 20),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (!_isSmallPhone)
                            Text(
                              _getBMICategory(bmi),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: _isSmallPhone ? 16 : 20),

              // Grid de métricas principales
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio:
                    _isSmallPhone ? 1.0 : (_isMediumPhone ? 1.1 : 1.2),
                mainAxisSpacing: _isSmallPhone ? 10 : 12,
                crossAxisSpacing: _isSmallPhone ? 10 : 12,
                children: [
                  _buildMetricCard(
                    title: 'PESO',
                    value: '${weight.toStringAsFixed(1)} kg',
                    subtitle: 'Peso total',
                    color: Colors.green,
                    analysis: _getWeightAnalysis(weight, height, gender),
                    icon: Icons.monitor_weight,
                  ),
                  _buildMetricCard(
                    title: 'ALTURA',
                    value: '${height.toStringAsFixed(1)} cm',
                    subtitle: 'Estatura',
                    color: Colors.blue,
                    analysis: 'Altura base para cálculos antropométricos.\n\n'
                        'Con ${height}cm, eres más alto que el promedio.\n'
                        'Esto afecta tu peso ideal y composición corporal.',
                    icon: Icons.height,
                  ),
                  _buildMetricCard(
                    title: 'GRASA',
                    value:
                        '${measurement['body_fat']?.toStringAsFixed(1) ?? 'N/A'}%',
                    subtitle: 'Porcentaje graso',
                    color: Colors.orange,
                    analysis: _getBodyFatAnalysis(
                      measurement['body_fat']?.toDouble() ?? 0,
                      gender,
                      weight,
                      waist,
                      height,
                    ),
                    icon: Icons.pie_chart,
                  ),
                  _buildMetricCard(
                    title: 'MÚSCULO',
                    value:
                        '${measurement['muscle_mass']?.toStringAsFixed(1) ?? 'N/A'} kg',
                    subtitle: 'Masa muscular',
                    color: Colors.purple,
                    analysis: _getMuscleAnalysis(
                      measurement['muscle_mass']?.toDouble() ?? 0,
                      weight,
                      gender,
                      height,
                    ),
                    icon: Icons.fitness_center,
                  ),
                  if (measurement['water_percentage'] != null)
                    _buildMetricCard(
                      title: 'AGUA',
                      value:
                          '${measurement['water_percentage']?.toStringAsFixed(1)}%',
                      subtitle: 'Hidratación',
                      color: Colors.cyan,
                      analysis:
                          'Hidratación corporal: ${measurement['water_percentage']?.toStringAsFixed(1)}%\n\n'
                          '• Normal: ${gender == 'male' ? '60%' : '55%'}\n'
                          '• Tu nivel: ${(measurement['water_percentage']?.toDouble() ?? 0) < (gender == 'male' ? 60 : 55) ? 'Puede mejorar' : 'Óptimo'}\n'
                          '• Importante para rendimiento y recuperación',
                      icon: Icons.water_drop,
                    ),
                  if (measurement['visceral_fat'] != null)
                    _buildMetricCard(
                      title: _isSmallPhone ? 'VISCERAL' : 'GRASA VISCERAL',
                      value: '${measurement['visceral_fat']}',
                      subtitle: 'Grasa abdominal',
                      color: Colors.red,
                      analysis:
                          'Grasa visceral nivel ${measurement['visceral_fat']}/12\n\n'
                          '• Nivel ${measurement['visceral_fat'] < 5 ? 'MUY BAJO' : measurement['visceral_fat'] < 9 ? 'NORMAL' : 'ALTO'}\n'
                          '• Grasa alrededor de órganos\n'
                          '• ${measurement['visceral_fat'] < 9 ? 'Riesgo bajo' : 'Considera reducir'}',
                      icon: Icons.warning,
                    ),
                ],
              ),

              // Métricas adicionales
              if (measurement['metabolic_age'] != null ||
                  measurement['bone_mass'] != null ||
                  measurement['body_type'] != null) ...[
                SizedBox(height: _isSmallPhone ? 16 : 20),
                Text(
                  _isSmallPhone ? 'MÁS MÉTRICAS' : 'MÉTRICAS ADICIONALES',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: _getFontSize(13, 14, 15),
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: _isSmallPhone ? 12 : 16),
                Column(
                  children: [
                    if (measurement['metabolic_age'] != null)
                      _buildAdditionalMetric(
                        title: '⏳ Edad Metabólica',
                        value: '${measurement['metabolic_age']} años',
                        color: Colors.purple,
                        analysis:
                            'Tu metabolismo funciona como el de alguien de ${measurement['metabolic_age']} años.\n'
                            '• Edad cronológica: ${measurement['age'] ?? '?'} años\n'
                            '• ${measurement['metabolic_age']! < measurement['age']! ? 'Más joven' : 'Mayor'} que tu edad real\n'
                            '• ${measurement['metabolic_age']! < measurement['age']! ? 'Excelente' : 'Considera mejorar'}',
                      ),
                    if (measurement['bone_mass'] != null)
                      _buildAdditionalMetric(
                        title: '🦴 Masa Ósea',
                        value:
                            '${measurement['bone_mass']?.toStringAsFixed(1)} kg',
                        color: Colors.brown,
                        analysis:
                            'Masa ósea: ${measurement['bone_mass']?.toStringAsFixed(1)}kg\n'
                            '• ${gender == 'male' ? 'Hombres:' : 'Mujeres:'} ${gender == 'male' ? '3-4kg' : '2.5-3.5kg'} normal\n'
                            '• Densidad ósea ${measurement['bone_mass']! > (gender == 'male' ? 3.5 : 3.0) ? 'excelente' : 'adecuada'}\n'
                            '• Importante para fuerza y prevención de lesiones',
                      ),
                    if (measurement['body_type'] != null)
                      _buildAdditionalMetric(
                        title: 'Tipo Corporal',
                        value: measurement['body_type'] ?? 'N/A',
                        color: Colors.green,
                        analysis: 'Somatotipo: ${measurement['body_type']}\n\n'
                            '• Ectomorfo: Delgado, metabolismo rápido\n'
                            '• Mesomorfo: Atlético, gana músculo fácil\n'
                            '• Endomorfo: Acumula grasa fácil, fuerte\n'
                            '• Balanceado: Mezcla de características\n\n'
                            'Estrategia según tu tipo',
                      ),
                  ],
                ),
              ],

              // Notas del entrenador
              if (measurement['notes'] != null &&
                  measurement['notes'].toString().isNotEmpty) ...[
                SizedBox(height: _isSmallPhone ? 16 : 20),
                Container(
                  padding: EdgeInsets.all(_isSmallPhone ? 12 : 14),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius:
                        BorderRadius.circular(_isSmallPhone ? 10 : 12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.sports_gymnastics,
                            color: Colors.blue,
                            size: _getIconSize(16, 17, 18),
                          ),
                          SizedBox(width: _isSmallPhone ? 6 : 8),
                          Text(
                            '💬 COMENTARIOS',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w800,
                              fontSize: _getFontSize(12, 13, 14),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: _isSmallPhone ? 6 : 8),
                      Text(
                        measurement['notes'].toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: _getFontSize(11, 12, 13),
                          height: 1.4,
                        ),
                        maxLines: 8,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Sección de medidas corporales
        _buildBodyMeasurementsSection(measurement),
      ],
    );
  }

  Widget _buildAdditionalMetric({
    required String title,
    required String value,
    required Color color,
    required String analysis,
  }) {
    return GestureDetector(
      onTap: () => _showAnalysisDialog(title, value, analysis, color),
      child: Container(
        margin: EdgeInsets.only(bottom: _isSmallPhone ? 8 : 10),
        padding: EdgeInsets.all(_isSmallPhone ? 10 : 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(_isSmallPhone ? 8 : 10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: _getFontSize(11, 12, 13),
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: _getFontSize(12, 13, 14),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: _isSmallPhone ? 4 : 6),
            Icon(
              Icons.info_outline,
              size: _getIconSize(12, 13, 14),
              color: color.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: _isSmallPhone ? 12 : 16,
      ),
      padding: EdgeInsets.all(_isSmallPhone ? 16 : 20),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(_isSmallPhone ? 14 : 16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(_isSmallPhone ? 8 : 10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline,
                  color: Colors.blue[300],
                  size: _isSmallPhone ? 18 : 20,
                ),
              ),
              SizedBox(width: _isSmallPhone ? 12 : 14),
              Text(
                'GUÍA DE INTERPRETACIÓN',
                style: TextStyle(
                  color: Colors.blue[300],
                  fontWeight: FontWeight.w800,
                  fontSize: _getFontSize(13, 14, 15),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: _isSmallPhone ? 14 : 16),
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.1),
          ),
          SizedBox(height: _isSmallPhone ? 14 : 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGuideItem(
                'Toca cualquier métrica para ver análisis completo y recomendaciones personalizadas.',
                Colors.cyan,
              ),
              SizedBox(height: _isSmallPhone ? 10 : 12),
              _buildGuideItem(
                'El peso ideal en el gym es diferente al ideal médico. Ganas músculo (pesas más).',
                Colors.green,
              ),
              SizedBox(height: _isSmallPhone ? 10 : 12),
              _buildGuideItem(
                'Lo importante es la TENDENCIA en el tiempo, no valores aislados.',
                Colors.orange,
              ),
              SizedBox(height: _isSmallPhone ? 10 : 12),
              _buildGuideItem(
                'Compara mediciones cada 2-4 semanas para ver cambios significativos.',
                Colors.purple,
              ),
              SizedBox(height: _isSmallPhone ? 10 : 12),
              _buildGuideItem(
                'Más músculo = mejor metabolismo, más fuerza y mejor apariencia física.',
                Colors.red[400]!,
              ),
            ],
          ),
          SizedBox(height: _isSmallPhone ? 14 : 16),
          Container(
            padding: EdgeInsets.all(_isSmallPhone ? 10 : 12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(_isSmallPhone ? 10 : 12),
            ),
            child: Text(
              _isSmallPhone
                  ? 'Peso gym ≠ peso médico'
                  : 'NOTA IMPORTANTE: El peso ideal para entrenar es diferente al peso ideal médico.',
              style: TextStyle(
                color: Colors.blue[300],
                fontSize: _getFontSize(11, 12, 13),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideItem(String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check,
            size: 12,
            color: color,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: _getFontSize(12, 13, 13),
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.all(_isSmallPhone ? 24 : 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.scale,
            size: _getFontSize(60, 70, 80),
            color: Colors.grey[700],
          ),
          SizedBox(height: _isSmallPhone ? 16 : 20),
          Text(
            _isSmallPhone ? 'SIN MEDICIONES' : 'SIN MEDICIONES REGISTRADAS',
            style: TextStyle(
              color: Colors.white,
              fontSize: _getFontSize(18, 20, 22),
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: _isSmallPhone ? 8 : 12),
          Text(
            _isSmallPhone
                ? 'Tu entrenador aún no ha registrado tus medidas.'
                : 'Tu entrenador aún no ha registrado tus medidas corporales.\n\n'
                    'Cuando lo haga, aquí podrás ver tu evolución completa.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: _getFontSize(12, 13, 14),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: _isSmallPhone ? 20 : 24),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              padding: EdgeInsets.symmetric(
                horizontal: _isSmallPhone ? 24 : 32,
                vertical: _isSmallPhone ? 14 : 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_isSmallPhone ? 10 : 12),
              ),
            ),
            child: Text(
              _isSmallPhone ? '🔄 RECARGAR' : '🔄 ¿YA TE MIDIERON? RECARGAR',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: _getFontSize(13, 14, 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBMIColor(double bmi) {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25) return Colors.green;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
  }

  String _getBMICategory(double bmi) {
    if (bmi < 18.5) return 'BAJO';
    if (bmi < 25) return 'NORMAL';
    if (bmi < 30) return 'SOBREPESO';
    return 'OBESIDAD';
  }

  @override
  Widget build(BuildContext context) {
    final hasMeasurements = _measurements.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ANÁLISIS CORPORAL',
              style: TextStyle(
                fontSize: _getFontSize(14, 16, 18),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            if (hasMeasurements && !_isSmallPhone)
              Text(
                '${_measurements.length} mediciones registradas',
                style: TextStyle(
                  fontSize: _getFontSize(9, 10, 11),
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        backgroundColor: AppTheme.darkBlack,
        elevation: 0,
        toolbarHeight: _isSmallPhone ? 56 : 64,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              size: _getIconSize(20, 22, 24),
            ),
            onPressed: _loadData,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryOrange),
                  SizedBox(height: _isSmallPhone ? 12 : 16),
                  Text(
                    _isSmallPhone ? 'Cargando...' : 'Analizando composición...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: _getFontSize(13, 14, 15),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppTheme.primaryOrange,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    if (hasMeasurements) ...[
                      _buildMeasurementSelector(),
                      if (_measurements.length > 1) _buildProgressReport(),
                      if (_selectedMeasurementIndex != null)
                        _buildMeasurementCard(
                          _measurements[_selectedMeasurementIndex!],
                        ),
                      SizedBox(height: _isSmallPhone ? 16 : 24),
                      _buildInfoCard(),
                      SizedBox(height: _isSmallPhone ? 20 : 32),
                    ] else
                      _buildEmptyState(),
                  ],
                ),
              ),
            ),
    );
  }
}
