
import 'package:flutter/material.dart';

import '../../core/services/destination_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/url_launcher_helper.dart';
import 'destination_risk_screen.dart';

class DestinationsSheet extends StatefulWidget {
  final TouristDestination? currentSelection;
  final ValueChanged<TouristDestination?> onSelectDestination;

  const DestinationsSheet({
    super.key,
    this.currentSelection,
    required this.onSelectDestination,
  });

  @override
  State<DestinationsSheet> createState() => _DestinationsSheetState();
}

class _DestinationsSheetState extends State<DestinationsSheet> {
  final DestinationService _destinationService = DestinationService();
  final TextEditingController _searchController =
      TextEditingController();

  List<TouristDestination> _allCurated = [];
  List<TouristDestination> _filteredCurated = [];
  List<TouristDestination> _osmSearchResults = [];

  String _selectedRegionFilter = 'All';

  bool _isLoading = true;
  bool _isSearchingOsm = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadDestinations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Load the destinations supplied by DestinationService.
  Future<void> _loadDestinations() async {
    try {
      final destinations =
          await _destinationService.getDestinations();

      if (!mounted) return;

      setState(() {
        _allCurated = destinations;
        _filteredCurated = _getFilteredDestinations();
        _isLoading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load destinations. Please try again.';
      });
    }
  }

  List<TouristDestination> _getFilteredDestinations() {
    final query = _searchController.text.trim().toLowerCase();

    return _allCurated.where((destination) {
      final matchesRegion =
          _selectedRegionFilter == 'All' ||
          (_selectedRegionFilter == 'Maharashtra' &&
              destination.state.toLowerCase() == 'maharashtra') ||
          (_selectedRegionFilter == 'Other India' &&
              destination.state.toLowerCase() != 'maharashtra');

      if (!matchesRegion) return false;
      if (query.isEmpty) return true;

      return destination.matchesSearch(query);
    }).toList();
  }

  void _applyFilter() {
    setState(() {
      _filteredCurated = _getFilteredDestinations();
      _osmSearchResults = [];
    });
  }

  // Search for a destination online using DestinationService.
  Future<void> _searchOnlinePlace() async {
    final query = _searchController.text.trim();

    if (query.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter at least 2 characters to search.'),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSearchingOsm = true;
      _osmSearchResults = [];
    });

    try {
      final results =
          await _destinationService.searchCustomPlaceInIndia(query);

      if (!mounted) return;

      setState(() {
        _osmSearchResults = results;
        _isSearchingOsm = false;
      });

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No online places found. Try another destination name.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSearchingOsm = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Online search failed. Check your internet connection.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // Sheet handle.
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              // Header.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.travel_explore,
                      color: AppTheme.teal,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Explore Tourist Destinations',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Explore destinations and check safety risk before visiting',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Current destination selection.
              if (widget.currentSelection != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.tealTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.gps_fixed,
                          size: 18,
                          color: AppTheme.tealDark,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Currently browsing: '
                            '${widget.currentSelection!.name}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.tealDark,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            widget.onSelectDestination(null);
                            Navigator.pop(context);
                          },
                          child: const Text('Use Live GPS'),
                        ),
                      ],
                    ),
                  ),
                ),

              // Verified Dataset Disclaimer Banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.tealTint.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.teal.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.verified, color: AppTheme.teal, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Verified Government Dataset: All 113+ Maharashtra & India locations, risk factors, and emergency helplines are strictly compiled from State CID, NCRB, and police emergency datasets — not arbitrary internet web scraping.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.tealDark,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Search field at top.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => _applyFilter(),
                  onSubmitted: (_) => _searchOnlinePlace(),
                  decoration: InputDecoration(
                    hintText:
                        'Search 113+ destinations (Mumbai, Pune, Alibag, Shirdi...)',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.teal),
                    suffixIcon: _searchController.text.trim().isNotEmpty
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _applyFilter();
                                },
                              ),
                              IconButton(
                                tooltip: 'Search online OSM',
                                onPressed: _isSearchingOsm ? null : _searchOnlinePlace,
                                icon: const Icon(Icons.public, color: AppTheme.teal),
                              ),
                            ],
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.surfaceBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.teal,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

              // Region filters with counts.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Row(
                  children: [
                    'All (${_allCurated.length})',
                    'Maharashtra (${_allCurated.where((d) => d.state.toLowerCase() == 'maharashtra').length})',
                    'Other India (${_allCurated.where((d) => d.state.toLowerCase() != 'maharashtra').length})'
                  ].map((labelWithCount) {
                    final rawRegion = labelWithCount.startsWith('All')
                        ? 'All'
                        : labelWithCount.startsWith('Maharashtra')
                            ? 'Maharashtra'
                            : 'Other India';
                    final selected = _selectedRegionFilter == rawRegion;

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(labelWithCount, style: const TextStyle(fontSize: 11)),
                        selected: selected,
                        selectedColor: AppTheme.tealTint,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) {
                          setState(() {
                            _selectedRegionFilter = rawRegion;
                            _filteredCurated = _getFilteredDestinations();
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 6),

              // Destination list.
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : _buildDestinationList(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDestinationList(
    ScrollController scrollController,
  ) {
    if (_loadError != null && _allCurated.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 42,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _loadError = null;
                  });
                  _loadDestinations();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        if (_isSearchingOsm)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),

        if (_osmSearchResults.isNotEmpty) ...[
          const Text(
            'OpenStreetMap Search Results',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.tealDark,
            ),
          ),
          const SizedBox(height: 8),
          ..._osmSearchResults.map(_buildDestinationCard),
          const Divider(height: 24),
        ],

        Text(
          'Curated Tourist Destinations '
          '(${_filteredCurated.length})',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.muted,
          ),
        ),

        const SizedBox(height: 8),

        if (_filteredCurated.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                const Icon(
                  Icons.location_off_outlined,
                  size: 36,
                  color: AppTheme.muted,
                ),
                const SizedBox(height: 8),
                const Text(
                  'No matching destination in the curated list.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isSearchingOsm
                      ? null
                      : _searchOnlinePlace,
                  icon: const Icon(Icons.public, size: 18),
                  label: const Text('Search Online'),
                ),
              ],
            ),
          ),

        ..._filteredCurated.map(_buildDestinationCard),
      ],
    );
  }

  Widget _buildDestinationCard(TouristDestination dest) {
    final isSelected =
        widget.currentSelection?.id == dest.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected
              ? AppTheme.teal
              : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Destination name and Explore Area button.
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppTheme.tealTint,
                  child: Icon(
                    Icons.place,
                    color: AppTheme.tealDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${dest.name}, ${dest.state}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        dest.category,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  onPressed: () {
                    widget.onSelectDestination(dest);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.teal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: const Text(
                    'Explore Area',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Existing source and safety advisory.
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 15,
                        color: AppTheme.tealDark,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          dest.source,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.tealDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dest.safetyAdvisory,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
            ),

            if (dest.nearestPoliceStation != null || dest.nearestHospital != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    if (dest.nearestPoliceStation != null)
                      Row(
                        children: [
                          const Icon(Icons.local_police, size: 14, color: Colors.blue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              dest.nearestPoliceStation!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Text(
                            'Police',
                            style: TextStyle(fontSize: 10, color: AppTheme.muted),
                          ),
                        ],
                      ),
                    if (dest.nearestPoliceStation != null && dest.nearestHospital != null)
                      const SizedBox(height: 4),
                    if (dest.nearestHospital != null)
                      Row(
                        children: [
                          const Icon(Icons.local_hospital, size: 14, color: Colors.red),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              dest.nearestHospital!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Text(
                            'Hospital',
                            style: TextStyle(fontSize: 10, color: AppTheme.muted),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Existing emergency and tourist helplines.
            Wrap(
              spacing: 4,
              runSpacing: 0,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      UrlLauncherHelper.callNumber(
                    context,
                    dest.emergencyHelpline,
                  ),
                  icon: const Icon(
                    Icons.call,
                    size: 15,
                  ),
                  label: Text(
                    'ERSS ${dest.emergencyHelpline}',
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      UrlLauncherHelper.callNumber(
                    context,
                    dest.touristHelpline,
                  ),
                  icon: const Icon(
                    Icons.support_agent,
                    size: 15,
                  ),
                  label: Text(
                    'Tourist Helpline ${dest.touristHelpline}',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // NEW: Open the destination-specific risk screen.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(
                  Icons.health_and_safety_outlined,
                ),
                label: const Text(
                  'Check Risk Before Visiting',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.teal,
                  side: const BorderSide(
                    color: AppTheme.teal,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DestinationRiskScreen(
                        destination: dest,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
