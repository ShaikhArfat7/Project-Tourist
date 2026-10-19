import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/crime_data_service.dart';
import '../../core/services/weather_service.dart';
import '../../core/theme/app_theme.dart';

class CrimeAnalysisScreen extends StatefulWidget {
  const CrimeAnalysisScreen({super.key});

  @override
  State<CrimeAnalysisScreen> createState() => _CrimeAnalysisScreenState();
}

class _CrimeAnalysisScreenState extends State<CrimeAnalysisScreen> with SingleTickerProviderStateMixin {
  final CrimeDataService _crimeService = CrimeDataService();
  final WeatherService _weatherService = WeatherService();

  late TabController _tabController;
  bool _isLoading = true;

  // Selected entities
  StateCrimeRecord? _selectedState;
  DistrictCrimeRecord? _selectedDistrict;
  int _selectedDistrictYear = 2023;

  // Weather state
  WeatherData? _weatherData;
  bool _isLoadingWeather = false;
  String? _weatherError;

  // Search queries for tables
  String _stateSearchQuery = '';
  String _districtSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
        _refreshWeatherForActiveTab();
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _crimeService.initialize();

    if (_crimeService.states.isNotEmpty) {
      _selectedState = _crimeService.getStateByName('Maharashtra') ?? _crimeService.states.first;
    }
    if (_crimeService.districts.isNotEmpty) {
      _selectedDistrictYear = _crimeService.availableDistrictYears.firstOrNull ?? 2023;
      _selectedDistrict = _crimeService.getDistrictByName('Raigad', year: _selectedDistrictYear) ??
          _crimeService.getDistricts(year: _selectedDistrictYear).firstOrNull ??
          _crimeService.districts.first;
    }

    if (mounted) {
      setState(() => _isLoading = false);
      _refreshWeatherForActiveTab();
    }
  }

  Future<void> _refreshWeatherForActiveTab() async {
    double lat = 18.9220;
    double lng = 72.8347;
    String name = 'Maharashtra';

    if (_tabController.index == 0 && _selectedState != null) {
      lat = _selectedState!.latitude;
      lng = _selectedState!.longitude;
      name = '${_selectedState!.stateUt} (${_selectedState!.capital})';
    } else if (_tabController.index == 1 && _selectedDistrict != null) {
      lat = _selectedDistrict!.latitude;
      lng = _selectedDistrict!.longitude;
      name = '${_selectedDistrict!.district} (${_selectedDistrict!.headquarters})';
    } else {
      return;
    }

    setState(() {
      _isLoadingWeather = true;
      _weatherError = null;
    });

    try {
      final weather = await _weatherService.fetchWeather(
        latitude: lat,
        longitude: lng,
        locationName: name,
      );
      if (mounted) {
        setState(() {
          _weatherData = weather;
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _weatherError = 'Could not retrieve live weather: $e';
          _isLoadingWeather = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Public Safety & Crime Analytics',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              'Verified Government Data (NCRB & Maharashtra Police)',
              style: TextStyle(fontSize: 11, color: AppTheme.tealTint),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Data Sources & Methodology',
            onPressed: _showMetadataDialog,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Upload Custom Dataset',
            onPressed: _showUploadModal,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.cautionAmber,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.public, size: 20), text: 'State Level'),
            Tab(icon: Icon(Icons.location_city, size: 20), text: 'MH Districts'),
            Tab(icon: Icon(Icons.folder_open, size: 20), text: 'Custom Data'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.teal))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStateLevelView(),
                _buildDistrictLevelView(),
                _buildCustomDataView(),
              ],
            ),
    );
  }

  // ==========================================
  // LEVEL A: STATE-LEVEL VIEW (NCRB)
  // ==========================================
  Widget _buildStateLevelView() {
    if (_selectedState == null) {
      return const Center(child: Text('No State data available.'));
    }

    final state = _selectedState!;
    final totalIpc = state.ipcCrimes2016;

    return RefreshIndicator(
      onRefresh: _refreshWeatherForActiveTab,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSourceNoticeBanner(
              level: 'Level A: State & Union Territory Analysis',
              source: 'NCRB Crime in India (2014–2016 Official Report)',
              rateNote: 'Rates calculated per 100,000 using official RGI projected population denominators.',
            ),
            const SizedBox(height: 16),

            // State Selector Dropdown
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.slateBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.map, color: AppTheme.teal),
                    const SizedBox(width: 12),
                    const Text('Select State / UT:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: state.stateUt,
                          isExpanded: true,
                          items: _crimeService.states.map((s) {
                            return DropdownMenuItem<String>(
                              value: s.stateUt,
                              child: Text(
                                s.stateUt,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedState = _crimeService.getStateByName(val);
                              });
                              _refreshWeatherForActiveTab();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Weather Integration Card
            _buildWeatherCard(),
            const SizedBox(height: 16),

            // Key Metric Cards Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total IPC Crimes',
                    value: state.ipcCrimes2016.toString(),
                    subtitle: 'Reporting Year: 2016',
                    icon: Icons.shield,
                    color: AppTheme.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Official Crime Rate',
                    value: '${state.crimeRate2016.toStringAsFixed(1)} / lakh',
                    subtitle: 'Per 100k population',
                    icon: Icons.speed,
                    color: state.crimeRate2016 > 250 ? AppTheme.cautionAmber : AppTheme.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Projected Population',
                    value: '${state.projectedPopulationLakhs2016.toStringAsFixed(1)} Lakhs',
                    subtitle: 'RGI 2016 projection',
                    icon: Icons.people_outline,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'National Share',
                    value: '${state.percentageShare2016.toStringAsFixed(1)}%',
                    subtitle: 'Of total India IPC',
                    icon: Icons.pie_chart_outline,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 3-Year Trend Comparison
            _buildYearTrendCard(state),
            const SizedBox(height: 20),

            // Crime Category Breakdown
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.slateBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bar_chart, color: AppTheme.teal),
                        SizedBox(width: 8),
                        Text(
                          'Cognizable IPC Breakdown (2016 Counts)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Incidence counts from official NCRB Table 1.2',
                      style: TextStyle(fontSize: 12, color: AppTheme.muted),
                    ),
                    const Divider(height: 24),
                    _buildCrimeBar('Theft (Property Crime)', state.theft2016, totalIpc, Colors.amber.shade800),
                    _buildCrimeBar('Burglary (Housebreaking)', state.burglary2016, totalIpc, Colors.orange),
                    _buildCrimeBar('Violent Crimes (Total)', state.violentCrimes2016, totalIpc, AppTheme.highRiskRed),
                    _buildCrimeBar('Assault on Women (IPC 354)', state.assaultOnWomen2016, totalIpc, Colors.purple),
                    _buildCrimeBar('Kidnapping & Abduction', state.kidnappingAndAbduction2016, totalIpc, Colors.deepPurple),
                    _buildCrimeBar('Robbery', state.robbery2016, totalIpc, Colors.red.shade700),
                    _buildCrimeBar('Murder (IPC 302)', state.murder2016, totalIpc, Colors.red.shade900),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // All States Comparison Table
            _buildStatesTable(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // LEVEL B: MAHARASHTRA DISTRICT-LEVEL VIEW
  // ==========================================
  Widget _buildDistrictLevelView() {
    if (_selectedDistrict == null) {
      return const Center(child: Text('No Maharashtra District data available.'));
    }

    final dist = _selectedDistrict!;
    final totalIpc = dist.totalIpcCrimes;

    return RefreshIndicator(
      onRefresh: _refreshWeatherForActiveTab,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSourceNoticeBanner(
              level: 'Level B: Maharashtra District & Commissionerate Analysis',
              source: 'State CID Maharashtra (Crime in Maharashtra ${dist.reportingYear} Report)',
              rateNote: dist.populationDenominatorAvailable
                  ? 'Official population denominators from Directorate of Economics & Statistics / State CID. Crime rates calculated per 100,000 population.'
                  : 'Rate is NOT calculated. Police Commissionerate boundaries do not have separate census population denominators.',
            ),
            const SizedBox(height: 16),

            // District & Year Selector Dropdown
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.slateBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppTheme.teal, size: 16),
                        const SizedBox(width: 8),
                        const Text('Reporting Year:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const Spacer(),
                        ..._crimeService.availableDistrictYears.map((yr) {
                          final isSel = yr == _selectedDistrictYear;
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: ChoiceChip(
                              label: Text('$yr', style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                              selected: isSel,
                              selectedColor: AppTheme.tealTint,
                              onSelected: (_) {
                                setState(() {
                                  _selectedDistrictYear = yr;
                                  _selectedDistrict = _crimeService.getDistrictByName(dist.district, year: yr) ??
                                      _crimeService.getDistricts(year: yr).firstOrNull ?? dist;
                                });
                                _refreshWeatherForActiveTab();
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                    const Divider(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.location_pin, color: AppTheme.teal),
                        const SizedBox(width: 12),
                        const Text('Police Unit / District:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _crimeService.getDistricts(year: _selectedDistrictYear).any((d) => d.district == dist.district)
                                  ? dist.district
                                  : (_crimeService.getDistricts(year: _selectedDistrictYear).firstOrNull?.district),
                              isExpanded: true,
                              items: _crimeService.getDistricts(year: _selectedDistrictYear).map((d) {
                                return DropdownMenuItem<String>(
                                  value: d.district,
                                  child: Text(
                                    '${d.district} (${d.unitType})',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedDistrict = _crimeService.getDistrictByName(val, year: _selectedDistrictYear);
                                  });
                                  _refreshWeatherForActiveTab();
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Weather Integration Card
            _buildWeatherCard(),
            const SizedBox(height: 16),

            // Key Metric Cards Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total IPC Crimes',
                    value: dist.totalIpcCrimes.toString(),
                    subtitle: '${dist.reportingYear} Recorded Incidence',
                    icon: Icons.assignment_outlined,
                    color: AppTheme.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Jurisdiction Type',
                    value: dist.unitType,
                    subtitle: 'Region: ${dist.region}',
                    icon: Icons.domain,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Crime Rate Safeguard or Verified Rate Card
            if (dist.populationDenominatorAvailable && dist.crimeRate != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, color: AppTheme.teal, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Official IPC Crime Rate: ${dist.crimeRate!.toStringAsFixed(1)} per 100,000 population',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.tealDark),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Estimated Population: ${dist.populationLakhs ?? "N/A"} Lakhs  •  Women Safety Rate: ${dist.crimesAgainstWomenRate?.toStringAsFixed(1) ?? "N/A"} per 100k females  •  Total Cognizable Rate: ${dist.totalCrimeRate?.toStringAsFixed(1) ?? "N/A"}',
                            style: const TextStyle(fontSize: 11, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Crime Rate: Unavailable for District Police Jurisdictions',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.brown),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'In accordance with statistical integrity principles, crime rates are omitted where separate projected population denominators are not published.',
                            style: TextStyle(fontSize: 11, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // District Crime Breakdown
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.slateBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${dist.district} Breakdown (${dist.reportingYear})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'HQ: ${dist.headquarters}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildCrimeBar('Theft', dist.theft, totalIpc, Colors.amber.shade800),
                    _buildCrimeBar('Burglary (Housebreaking)', dist.burglary, totalIpc, Colors.orange),
                    _buildCrimeBar('Cheating & Forgery', dist.cheatingAndFraud, totalIpc, Colors.blueGrey),
                    _buildCrimeBar('Rape & Assault on Women', dist.rapeAndAssaultOnWomen, totalIpc, Colors.purple),
                    _buildCrimeBar('Dacoity & Robbery', dist.dacoityAndRobbery, totalIpc, Colors.red.shade700),
                    _buildCrimeBar('Kidnapping & Abduction', dist.kidnappingAndAbduction, totalIpc, Colors.deepPurple),
                    _buildCrimeBar('Attempt to Murder', dist.attemptToMurder, totalIpc, Colors.red.shade600),
                    _buildCrimeBar('Murder', dist.murder, totalIpc, Colors.red.shade900),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // All Maharashtra Police Units Table
            _buildDistrictsTable(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // LEVEL C: CUSTOM USER-UPLOADED DATASET VIEW
  // ==========================================
  Widget _buildCustomDataView() {
    final custom = _crimeService.activeCustomDataset;

    if (custom == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_upload_outlined, size: 64, color: AppTheme.teal),
              const SizedBox(height: 16),
              const Text(
                'No Custom Dataset Loaded',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Upload a CSV or JSON file manually downloaded from data.gov.in, NCRB, or police portals. The app will validate its columns, records, and missing values.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.muted),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.file_upload),
                label: const Text('Upload & Validate Dataset'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: _showUploadModal,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSourceNoticeBanner(
            level: 'Level C: User-Uploaded Dataset Active',
            source: 'File: ${custom.fileName} (${custom.format})',
            rateNote: custom.hasPopulationDenominator
                ? 'Population column detected in uploaded data.'
                : 'No population column detected. Crime rates are omitted to maintain statistical integrity.',
          ),
          const SizedBox(height: 16),

          // Uploaded Summary Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.slateBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Dataset Validation Report',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Replace File'),
                        onPressed: _showUploadModal,
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildMetaRow('File Name', custom.fileName),
                  _buildMetaRow('File Format', custom.format),
                  _buildMetaRow('Record Count', '${custom.recordCount} rows'),
                  _buildMetaRow('Detected Level', custom.detectedLevel),
                  _buildMetaRow('Detected Period', custom.detectedPeriod),
                  _buildMetaRow('Missing / Blank Values', '${custom.missingValuesCount} entries'),
                  _buildMetaRow('Columns Detected', custom.columns.join(', ')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Data Table
          const Text(
            'Uploaded Records Preview',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildCustomPreviewTable(custom),
        ],
      ),
    );
  }

  // ==========================================
  // WEATHER INTEGRATION CARD
  // ==========================================
  Widget _buildWeatherCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.slateBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.wb_sunny_outlined, color: AppTheme.cautionAmber, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Live Weather Context',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (_isLoadingWeather)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.teal),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: 'Refresh Weather',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _refreshWeatherForActiveTab,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _weatherData != null ? _weatherData!.locationName : 'Selected location weather',
              style: const TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
            const Divider(height: 20),

            if (_weatherError != null)
              Text(_weatherError!, style: const TextStyle(color: AppTheme.highRiskRed, fontSize: 12))
            else if (_weatherData != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '${_weatherData!.temperature.toStringAsFixed(1)}°C',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.teal),
                      ),
                      Text(
                        'Feels ${_weatherData!.apparentTemperature.toStringAsFixed(1)}°C',
                        style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        _weatherData!.conditionDescription,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Wind: ${_weatherData!.windSpeed.toStringAsFixed(1)} km/h',
                        style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '${_weatherData!.humidity}%',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Humidity',
                        style: TextStyle(fontSize: 11, color: AppTheme.muted),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 7-Day Forecast Row
              if (_weatherData!.dailyForecast.isNotEmpty) ...[
                const Text(
                  '7-Day Forecast:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.muted),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _weatherData!.dailyForecast.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final item = _weatherData!.dailyForecast[i];
                      final dayStr = item.date.length >= 5 ? item.date.substring(5) : item.date;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.slateBorder),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(dayStr, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              '${item.maxTemp.round()}° / ${item.minTemp.round()}°',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textDark),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ] else
              const Text('Weather data loading...', style: TextStyle(fontSize: 12)),

            const SizedBox(height: 12),
            // Mandatory Scientific Disclaimer
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 14, color: AppTheme.teal),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      WeatherData.disclaimer,
                      style: TextStyle(fontSize: 10, color: AppTheme.muted, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================
  Widget _buildSourceNoticeBanner({
    required String level,
    required String source,
    required String rateNote,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified, size: 16, color: AppTheme.teal),
              const SizedBox(width: 6),
              Text(
                level,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.teal, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Official Source: $source',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textDark),
          ),
          const SizedBox(height: 2),
          Text(
            rateNote,
            style: const TextStyle(fontSize: 11, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slateBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildYearTrendCard(StateCrimeRecord state) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.slateBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '3-Year Reported IPC Crime Incidence (2014–2016)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildYearColumn('2014', state.ipcCrimes2014),
                _buildYearColumn('2015', state.ipcCrimes2015),
                _buildYearColumn('2016', state.ipcCrimes2016, isLatest: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearColumn(String year, int count, {bool isLatest = false}) {
    return Column(
      children: [
        Text(
          year,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
            color: isLatest ? AppTheme.teal : AppTheme.muted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isLatest ? AppTheme.teal : AppTheme.textDark,
          ),
        ),
        if (isLatest)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('Latest', style: TextStyle(fontSize: 9, color: AppTheme.teal)),
          ),
      ],
    );
  }

  Widget _buildCrimeBar(String title, int count, int total, Color color) {
    final pct = total > 0 ? (count / total) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text(
                '$count (${(pct * 100).toStringAsFixed(1)}%)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppTheme.slateBorder,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppTheme.muted, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: AppTheme.textDark, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DATA TABLES
  // ==========================================
  Widget _buildStatesTable() {
    final filtered = _crimeService.states.where((s) {
      return s.stateUt.toLowerCase().contains(_stateSearchQuery.toLowerCase());
    }).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.slateBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'All-India State/UT Crime Table (2016 NCRB)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search State / UT...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (val) => setState(() => _stateSearchQuery = val),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 18,
                headingRowColor: WidgetStateProperty.all(AppTheme.surfaceLight),
                columns: const [
                  DataColumn(label: Text('State / UT', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('2016 Crimes', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Rate / Lakh', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('% Share', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Population (Lakhs)', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: filtered.map((s) {
                  final isSelected = s.stateUt == _selectedState?.stateUt;
                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (_) {
                      setState(() => _selectedState = s);
                      _refreshWeatherForActiveTab();
                    },
                    cells: [
                      DataCell(Text(s.stateUt, style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(s.category)),
                      DataCell(Text(s.ipcCrimes2016.toString())),
                      DataCell(Text(s.crimeRate2016.toStringAsFixed(1))),
                      DataCell(Text('${s.percentageShare2016.toStringAsFixed(1)}%')),
                      DataCell(Text(s.projectedPopulationLakhs2016.toStringAsFixed(1))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistrictsTable() {
    final filtered = _crimeService.districts.where((d) {
      return d.district.toLowerCase().contains(_districtSearchQuery.toLowerCase()) ||
          d.region.toLowerCase().contains(_districtSearchQuery.toLowerCase());
    }).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.slateBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Maharashtra Police Units (43 Units, 2014)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search District or Region...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (val) => setState(() => _districtSearchQuery = val),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                headingRowColor: WidgetStateProperty.all(AppTheme.surfaceLight),
                columns: const [
                  DataColumn(label: Text('Police Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Unit Type', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Region', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Total IPC', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Theft', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Burglary', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Women Safety', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: filtered.map((d) {
                  final isSelected = d.district == _selectedDistrict?.district;
                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (_) {
                      setState(() => _selectedDistrict = d);
                      _refreshWeatherForActiveTab();
                    },
                    cells: [
                      DataCell(Text(d.district, style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(d.unitType)),
                      DataCell(Text(d.region)),
                      DataCell(Text(d.totalIpcCrimes.toString())),
                      DataCell(Text(d.theft.toString())),
                      DataCell(Text(d.burglary.toString())),
                      DataCell(Text(d.rapeAndAssaultOnWomen.toString())),
                      const DataCell(Text('N/A', style: TextStyle(color: AppTheme.muted, fontSize: 11))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomPreviewTable(DatasetValidationReport report) {
    if (report.parsedRows.isEmpty) {
      return const Text('No rows to preview.');
    }

    final cols = report.columns.take(6).toList();
    final rows = report.parsedRows.take(15).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: cols.map((c) => DataColumn(label: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
        rows: rows.map((r) {
          return DataRow(
            cells: cols.map((c) => DataCell(Text(r[c]?.toString() ?? ''))).toList(),
          );
        }).toList(),
      ),
    );
  }

  // ==========================================
  // METADATA & UPLOAD DIALOGS
  // ==========================================
  void _showMetadataDialog() {
    final meta = _crimeService.metadata;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.verified, color: AppTheme.teal),
              SizedBox(width: 8),
              Text('Official Sources & Licensing'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Licensing & Terms:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meta?['license_information']?['license'] ?? 'Government Open Data License - India (GODL)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.teal),
                  ),
                  Text(
                    meta?['license_information']?['terms_summary'] ??
                        'Public datasets from data.gov.in and NCRB are freely accessible with mandatory attribution.',
                    style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Included Verified Datasets:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  const Text('1. NCRB State IPC Crimes (2014–2016)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const Text('• 36 States and Union Territories\n• Mid-year projected population denominator available\n• Source: National Crime Records Bureau, Ministry of Home Affairs', style: TextStyle(fontSize: 11, color: AppTheme.textDark)),
                  const SizedBox(height: 8),
                  const Text('2. Maharashtra State CID Crime & Rates (2022 & 2023)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const Text('• 49 Police Units / 36 Revenue District Groups across Maharashtra\n• Official Population Denominators and IPC/Cognizable Crime Rates\n• Head-wise breakdowns (Theft, Burglary, Women Safety, Robbery, Violent Crime)\n• Source: State CID Maharashtra (Crime in Maharashtra Annual Reports)', style: TextStyle(fontSize: 11, color: AppTheme.textDark)),
                  const SizedBox(height: 8),
                  const Text('3. Historical Maharashtra District Baseline (2014)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const Text('• 43 Police Units (Commissionerates & Rural Districts)\n• Raw incidence counts baseline\n• Source: Maharashtra State CID SCRB & NCRB', style: TextStyle(fontSize: 11, color: AppTheme.textDark)),
                  const Divider(height: 24),
                  const Text(
                    'Environmental Context Disclaimer:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Open-Meteo weather integration is strictly provided as tourist contextual environmental info. The app makes no unscientific claims of weather predicting crime.',
                    style: TextStyle(fontSize: 11, color: AppTheme.muted),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showUploadModal() async {
    final pasteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Upload Crime Dataset',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Accepts CSV or JSON datasets downloaded from official portals.',
                  style: TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
                const SizedBox(height: 16),

                // File Picker Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Choose File from Device (CSV / JSON)'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      try {
                        final file = await FilePicker.pickFile(
                          type: FileType.custom,
                          allowedExtensions: ['csv', 'json', 'txt'],
                        );

                        if (file != null) {
                          final content = await file.xFile.readAsString();
                          if (!ctx.mounted) return;
                          if (content.isNotEmpty) {
                            Navigator.pop(ctx);
                            _processAndValidateUpload(file.name, content);
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('File pick error: $e')),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('OR PASTE RAW DATA', style: TextStyle(fontSize: 11, color: AppTheme.muted)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pasteController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'Paste CSV text or JSON array here...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Validate & Activate Dataset'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      final text = pasteController.text.trim();
                      if (text.isEmpty) return;
                      Navigator.pop(ctx);
                      final name = text.startsWith('[') ? 'pasted_dataset.json' : 'pasted_dataset.csv';
                      _processAndValidateUpload(name, text);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _processAndValidateUpload(String fileName, String content) {
    final report = _crimeService.validateAndParseUpload(
      fileName: fileName,
      content: content,
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                report.isValid ? Icons.check_circle : Icons.error_outline,
                color: report.isValid ? AppTheme.teal : AppTheme.highRiskRed,
              ),
              const SizedBox(width: 8),
              const Text('Dataset Validation'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!report.isValid)
                  Text(
                    report.errorMessage ?? 'Validation failed.',
                    style: const TextStyle(color: AppTheme.highRiskRed, fontWeight: FontWeight.bold),
                  )
                else ...[
                  _buildMetaRow('File Name', report.fileName),
                  _buildMetaRow('Format', report.format),
                  _buildMetaRow('Valid Records', '${report.recordCount} rows'),
                  _buildMetaRow('Detected Level', report.detectedLevel),
                  _buildMetaRow('Reporting Period', report.detectedPeriod),
                  _buildMetaRow('Missing Values', '${report.missingValuesCount} blank cells'),
                  _buildMetaRow('Population Column', report.hasPopulationDenominator ? 'Detected' : 'Not found (rates omitted)'),
                  const SizedBox(height: 8),
                  Text(
                    'Columns (${report.columns.length}):\n${report.columns.join(", ")}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            if (report.isValid)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.teal, foregroundColor: Colors.white),
                onPressed: () {
                  _crimeService.setActiveCustomDataset(report);
                  Navigator.pop(ctx);
                  _tabController.animateTo(2);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Dataset "${report.fileName}" activated successfully!')),
                  );
                },
                child: const Text('Activate Dataset'),
              ),
          ],
        );
      },
    );
  }
}
