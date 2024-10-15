import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

// HealthDietInsightsPage UI
class HealthDietInsightsPage extends StatefulWidget {
  const HealthDietInsightsPage({super.key});

  @override
  HealthDietInsightsPageState createState() => HealthDietInsightsPageState();
}

class HealthDietInsightsPageState extends State<HealthDietInsightsPage> {
  final DietInsightsService _dietInsightsService = DietInsightsService();
  final HealthConditionService _healthConditionService =
      HealthConditionService();
  List<String> healthConditions = [];
  String selectedHealthCondition = 'General Health';
  Map<String, dynamic>? dietInsights;
  String recommendation = '';
  List<String> recentlyBoughtItems = [];

  late User user;

  @override
  void initState() {
    super.initState();
    _loadHealthConditions();
    _loadRecentlyBoughtItems();
    // Optionally initialize with a default health condition
    _healthConditionService
        .updateSelectedHealthCondition(selectedHealthCondition);
  }

  // Load health conditions from API
  void _loadHealthConditions() async {
    try {
      final conditions =
          await _healthConditionService.fetchHealthConditions(user as String);
      setState(() {
        healthConditions = conditions;
      });
    } catch (e) {
      print('Failed to load health conditions: $e');
    }
  }

  // Load recently bought items from Firestore
  void _loadRecentlyBoughtItems() async {
    try {
      String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('recentlyBoughtProductIds')
          .get();

      List<String> items = [];
      for (var doc in snapshot.docs) {
        items.add(doc['item']);
      }

      setState(() {
        recentlyBoughtItems = items;
        _calculateDietInsights();
      });
    } catch (e) {
      print('Error fetching recently bought items: $e');
    }
  }

  // Calculate diet insights based on recently bought items
  void _calculateDietInsights() async {
    try {
      final insights =
          await _dietInsightsService.getDietInsights(recentlyBoughtItems);
      final recommendation = _dietInsightsService.generateRecommendation(
          insights, selectedHealthCondition);
      setState(() {
        dietInsights = insights;
        this.recommendation = recommendation as String;
      });
    } catch (e) {
      print('Error calculating diet insights: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diet Insights Based on Health Conditions'),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Example of how you can listen to the stream in your widget
            StreamBuilder<String>(
              stream: _healthConditionService
                  .healthConditionStream, // Accessing the stream from the service
              initialData: selectedHealthCondition,
              builder: (context, snapshot) {
                return Text('Selected Health Condition: ${snapshot.data}');
              },
            ),
            // Dropdown to select health condition
            DropdownButton<String>(
              value: selectedHealthCondition,
              icon: const Icon(Icons.arrow_downward),
              iconSize: 24,
              elevation: 16,
              style: const TextStyle(color: Colors.blue, fontSize: 18),
              underline: Container(
                height: 2,
                color: Colors.blueAccent,
              ),
              onChanged: (String? newCondition) {
                setState(() {
                  selectedHealthCondition = newCondition!;
                  _calculateDietInsights(); // Recalculate insights when condition changes
                });
              },
              items: healthConditions
                  .map<DropdownMenuItem<String>>((String condition) {
                return DropdownMenuItem<String>(
                  value: condition,
                  child: Text(condition),
                );
              }).toList(),
            ),
            // Glassmorphic Card to display diet insights and recommendation
            if (dietInsights != null) ...[
              GlassmorphicCard(
                title: 'Diet Insights',
                content: 'Calories: ${dietInsights!['totalCalories']} kcal\n'
                    'Sugars: ${dietInsights!['totalSugars']}g\n'
                    'Carbs: ${dietInsights!['totalCarbs']}g\n'
                    'Proteins: ${dietInsights!['totalProteins']}g\n'
                    'Fats: ${dietInsights!['totalFats']}g',
                child: const Text(''),
              ),
              const SizedBox(height: 20),
              GlassmorphicCard(
                title: 'Recommendation',
                content: recommendation,
                child: const Text(''),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class HealthConditionService {
  final String _apiKey = 'YOUR_API_KEY';
  final String _baseUrl = 'https://api.healthconditions.com/conditions';

  // Singleton pattern to ensure a single instance of this service
  static final HealthConditionService _instance =
      HealthConditionService._internal();

  factory HealthConditionService() {
    return _instance;
  }

  HealthConditionService._internal();

  // StreamController to manage health condition stream
  final StreamController<String> _healthConditionStreamController =
      StreamController<String>.broadcast();

  // Getter to expose the health condition stream
  Stream<String> get healthConditionStream =>
      _healthConditionStreamController.stream;

  // Function to update the selected health condition
  void updateSelectedHealthCondition(String newCondition) {
    _healthConditionStreamController.add(newCondition);
  }

  // Dispose method to close the stream (if needed)
  void dispose() {
    _healthConditionStreamController.close();
  }

  // Function to fetch health conditions from Firestore for a specific user
  Future<List<String>> _fetchHealthConditionsFromFirestore(String user) async {
    final userConditionCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(user)
        .collection('health_conditions');

    final snapshot = await userConditionCollection.get();
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.map((doc) => doc['name'].toString()).toList();
    } else {
      return [];
    }
  }

  // Function to fetch list of health conditions from API for a specific user and store in Firestore
  Future<List<String>> fetchHealthConditions(String userId) async {
    // Check if health conditions are already stored in Firestore for this user
    final conditionsFromFirestore =
        await _fetchHealthConditionsFromFirestore(userId);
    if (conditionsFromFirestore.isNotEmpty) {
      return conditionsFromFirestore;
    }

    // Fetch health conditions from the API
    final response = await http.get(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> conditions = jsonDecode(response.body)['conditions'];
      final List<String> conditionNames =
          conditions.map((condition) => condition['name'].toString()).toList();

      // Save the health conditions to Firestore for this user
      await _saveHealthConditionsToFirestore(userId, conditionNames);

      return conditionNames;
    } else {
      throw Exception('Failed to load health conditions');
    }
  }

  // Function to save health conditions to Firestore for a specific user
  Future<void> _saveHealthConditionsToFirestore(
      String userId, List<String> conditions) async {
    final userConditionCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('health_conditions');

    final batch = FirebaseFirestore.instance.batch();
    for (var condition in conditions) {
      final docRef = userConditionCollection.doc(condition);
      batch.set(docRef, {'name': condition});
    }
    await batch.commit();
  }
}

// NutritionService to fetch nutritional data from API
class NutritionService {
  final String _apiKey = 'YOUR_NUTRITION_API_KEY';
  final String _baseUrl =
      'https://trackapi.nutritionix.com/v2/natural/nutrients';

  // Function to fetch nutritional data for a given food item
  Future<Map<String, dynamic>> fetchFoodData(String foodItem) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'x-app-id': 'YOUR_APP_ID',
        'x-app-key': _apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'query': foodItem,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load nutritional data for $foodItem');
    }
  }
}

// DietInsightsService to analyze and generate recommendations
class DietInsightsService {
  final NutritionService _nutritionService = NutritionService();

  Future<Map<String, dynamic>> getDietInsights(List<String> boughtItems) async {
    double totalCalories = 0;
    double totalSugars = 0;
    double totalCarbs = 0;
    double totalProteins = 0;
    double totalFats = 0;

    for (String item in boughtItems) {
      try {
        final nutritionData = await _nutritionService.fetchFoodData(item);
        if (nutritionData['foods'] != null &&
            nutritionData['foods'].isNotEmpty) {
          final food = nutritionData['foods'][0];
          totalCalories += food['nf_calories'] ?? 0;
          totalSugars += food['nf_sugars'] ?? 0;
          totalCarbs += food['nf_total_carbohydrate'] ?? 0;
          totalProteins += food['nf_protein'] ?? 0;
          totalFats += food['nf_total_fat'] ?? 0;
        }
      } catch (e) {
        print('Error fetching nutritional data for $item: $e');
      }
    }

    return {
      'totalCalories': totalCalories,
      'totalSugars': totalSugars,
      'totalCarbs': totalCarbs,
      'totalProteins': totalProteins,
      'totalFats': totalFats,
    };
  }

  /// Generates a personalized recommendation using ChatGPT API based on health conditions and diet insights.
  Future<String> generateRecommendation(
      Map<String, dynamic> insights, String healthCondition) async {
    const apiKey = 'YOUR_API_KEY'; // Replace with your OpenAI API key

    // Construct a prompt with health insights and condition
    String prompt = '''
    Given the following diet insights:
    - Calories: ${insights['totalCalories']}
    - Sugars: ${insights['totalSugars']}
    - Carbs: ${insights['totalCarbs']}
    - Proteins: ${insights['totalProteins']}
    - Fats: ${insights['totalFats']}
    
    Generate a recommendation for someone with the following health condition: $healthCondition.
    ''';

    // Set up the request headers and payload
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    final body = jsonEncode({
      'model':
          'gpt-3.5-turbo', // Use 'gpt-3.5-turbo' or 'gpt-4' depending on your needs
      'messages': [
        {'role': 'system', 'content': 'You are a nutrition expert.'},
        {'role': 'user', 'content': prompt}
      ],
      'max_tokens': 150, // Limit the response length
    });

    // Send the POST request to OpenAI's ChatGPT API endpoint
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: headers,
      body: body,
    );

    // Check if the response is successful
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      final chatResponse = jsonResponse['choices'][0]['message']['content'];
      return chatResponse.trim();
    } else {
      // Handle errors
      return 'Failed to generate recommendation: ${response.statusCode} - ${response.body}';
    }
  }
}

// NutritionDashboard which integrates DietInsightsService
class NutritionDashboard extends StatefulWidget {
  const NutritionDashboard({super.key});

  @override
  NutritionDashboardState createState() => NutritionDashboardState();
}

class NutritionDashboardState extends State<NutritionDashboard> {
  final DietInsightsService _dietInsightsService = DietInsightsService();
  Map<String, dynamic> dietInsights = {};
  bool isLoading = true;
  String recommendation = '';
  final List<String> boughtItems = ['apple', 'banana', 'bread']; // Example data
  final String healthCondition = 'Weight Loss'; // Example condition
  List<FlSpot> lineChartData = [];

  @override
  void initState() {
    super.initState();
    _loadCalorieData();

    _loadDietInsights();
  }

  Future<void> _loadDietInsights() async {
    try {
      final insights = await _dietInsightsService.getDietInsights(boughtItems);
      final reco = _dietInsightsService.generateRecommendation(
          insights, healthCondition);
      setState(() {
        dietInsights = insights;
        recommendation = reco as String;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading diet insights: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadCalorieData() async {
    // Fetch calorie data over time (e.g., from backend or service)
    List<Map<String, dynamic>> dailyCalories = [
      {'day': 1, 'calories': 1800},
      {'day': 2, 'calories': 2000},
      {'day': 3, 'calories': 2200},
      {'day': 4, 'calories': 2100},
    ];

    setState(() {
      lineChartData = createLineChartData(dailyCalories);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition Dashboard')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const Text('Nutritional Breakdown'),
                  SizedBox(
                    height: 250,
                    child: GlassmorphicCard(
                      title: 'Pie Chart',
                      content: 'Nutritional Breakdown',
                      child: pieChart({
                        'Carbs': dietInsights['totalCarbs'] ?? 0,
                        'Proteins': dietInsights['totalProteins'] ?? 0,
                        'Fats': dietInsights['totalFats'] ?? 0,
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 250,
                    child: GlassmorphicCard(
                      title: 'Bar Chart',
                      content: 'Nutrient Intake',
                      child: barChart({
                        'Calories': dietInsights['totalCalories'] ?? 0,
                        'Sugars': dietInsights['totalSugars'] ?? 0,
                        'Carbs': dietInsights['totalCarbs'] ?? 0,
                      } as List<BarChartGroupData>),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 250,
                    child: GlassmorphicCard(
                      title: 'Line Chart',
                      content: 'Calories Over Time',
                      child: lineChart(createLineChartData(lineChartData.cast<
                          Map<String,
                              dynamic>>())), // You need to provide chart data for line chart
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 250,
                    child: GlassmorphicCard(
                      title: 'Radar Chart',
                      content: 'Nutrient Metrics',
                      child: radarChart(createRadarChartData(
                          dietInsights)), // You need to provide chart data for radar chart
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Display recommendation
                  Text(
                    'Recommendation: $recommendation',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
    );
  }

  Widget pieChart(Map<String, double> nutritionData) {
    return PieChart(
      PieChartData(
        sectionsSpace: 2, // Add spacing between sections
        startDegreeOffset: 180, // Rotate chart for better alignment
        sections: nutritionData.entries.map((entry) {
          return PieChartSectionData(
            title: entry.key,
            value: entry.value,
            color: Colors.blue.withOpacity(0.6), // Use semi-transparent colors
            showTitle: true, // Ensure title is visible
            titleStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            gradient: LinearGradient(
              // Adding gradient to sections
              colors: [Colors.blue.shade300, Colors.blue.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          );
        }).toList(),
      ),
      swapAnimationDuration:
          const Duration(milliseconds: 500), // Add smooth animation
    );
  }

  Widget barChart(List<BarChartGroupData> data) {
    return BarChart(
      BarChartData(
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: data,
        gridData: const FlGridData(show: false),
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          // Adding tooltips
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY}',
                const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }

  List<BarChartGroupData> createBarChartData(
      Map<String, dynamic> dietInsights) {
    return [
      BarChartGroupData(x: 0, barRods: [
        BarChartRodData(
          toY: dietInsights['totalCalories'] ?? 0,
          gradient: LinearGradient(
            // Adding gradient effect to the bar
            colors: [Colors.blue.shade300, Colors.blue.shade700],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          width: 16,
          borderRadius: BorderRadius.circular(8),
        ),
      ]),
      BarChartGroupData(x: 1, barRods: [
        BarChartRodData(
          toY: dietInsights['totalSugars'] ?? 0,
          gradient: LinearGradient(
            colors: [Colors.red.shade300, Colors.red.shade700],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          width: 16,
          borderRadius: BorderRadius.circular(8),
        ),
      ]),
      // Add more groups as needed
    ];
  }

  Widget lineChart(List<FlSpot> spots) {
    return LineChart(
      LineChartData(
        titlesData: const FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true),
          ),
        ),
        borderData: FlBorderData(show: true),
        gridData: const FlGridData(show: true, drawVerticalLine: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true, // Smooth the line curve
            gradient: LinearGradient(
              // Use gradient on the line
              colors: [Colors.blueAccent, Colors.blue.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            belowBarData: BarAreaData(
              // Shaded area below the curve
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.blueAccent.withOpacity(0.3),
                  Colors.blue.shade800.withOpacity(0.1)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> createLineChartData(List<Map<String, dynamic>> dailyCalories) {
    return dailyCalories.map((data) {
      return FlSpot(data['day'].toDouble(), data['calories'].toDouble());
    }).toList();
  }

  Widget radarChart(List<RadarEntry> metrics) {
    return RadarChart(
      RadarChartData(
        radarShape: RadarShape.circle, // Define the shape of the radar chart
        dataSets: [
          RadarDataSet(
            fillColor: Colors.green.withOpacity(0.3), // Add translucent fill
            borderColor: Colors.green,
            borderWidth: 3,
            entryRadius: 3, // Size of entry points
            dataEntries: metrics,
          ),
        ],
        radarBackgroundColor: Colors.transparent,
        borderData: FlBorderData(show: false),
        gridBorderData: const BorderSide(color: Colors.grey, width: 1),
        titlePositionPercentageOffset: 0.2, // Adjust label position
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 14),
      ),
    );
  }

  List<RadarEntry> createRadarChartData(Map<String, dynamic> dietInsights) {
    return [
      RadarEntry(value: dietInsights['totalCarbs'] ?? 0),
      RadarEntry(value: dietInsights['totalProteins'] ?? 0),
      RadarEntry(value: dietInsights['totalFats'] ?? 0),
      RadarEntry(value: dietInsights['totalSugars'] ?? 0),
    ];
  }
}

// Glassmorphic card with text that uses theme styles
class GlassmorphicCard extends StatelessWidget {
  final String title;
  final String content;

  const GlassmorphicCard(
      {super.key,
      required this.title,
      required this.content,
      required Widget child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Access the theme data

    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.orange.withOpacity(0.1)),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      theme.textTheme.titleLarge, // Use theme's headline6 style
                ),
                const SizedBox(height: 10),
                Text(
                  content,
                  style:
                      theme.textTheme.bodyMedium, // Use theme's bodyText2 style
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
