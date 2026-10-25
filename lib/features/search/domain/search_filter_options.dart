import '../../../shared/models/service_provider.dart';

enum SearchSortOption {
  recommended('Recommended'),
  nearest('Nearest to me'),
  highestRated('Highest Rated'),
  priceLowToHigh('Price: Low to High'),
  mostReviewed('Most Reviewed');

  final String label;
  const SearchSortOption(this.label);
}

class SearchFilterCriteria {
  final String query;
  final String? categoryId;
  final double? maxDistanceKm;
  final double? minRating;
  final int? maxPrice;
  final bool verifiedOnly;
  final SearchSortOption sortBy;

  const SearchFilterCriteria({
    this.query = '',
    this.categoryId,
    this.maxDistanceKm,
    this.minRating,
    this.maxPrice,
    this.verifiedOnly = false,
    this.sortBy = SearchSortOption.recommended,
  });

  bool get hasActiveFilters =>
      (categoryId != null && categoryId!.isNotEmpty) ||
      maxDistanceKm != null ||
      minRating != null ||
      maxPrice != null ||
      verifiedOnly ||
      sortBy != SearchSortOption.recommended;

  int get activeFilterCount {
    int count = 0;
    if (categoryId != null && categoryId!.isNotEmpty) count++;
    if (maxDistanceKm != null) count++;
    if (minRating != null) count++;
    if (maxPrice != null) count++;
    if (verifiedOnly) count++;
    if (sortBy != SearchSortOption.recommended) count++;
    return count;
  }

  SearchFilterCriteria copyWith({
    String? query,
    String? Function()? categoryId,
    double? Function()? maxDistanceKm,
    double? Function()? minRating,
    int? Function()? maxPrice,
    bool? verifiedOnly,
    SearchSortOption? sortBy,
  }) {
    return SearchFilterCriteria(
      query: query ?? this.query,
      categoryId: categoryId != null ? categoryId() : this.categoryId,
      maxDistanceKm: maxDistanceKm != null ? maxDistanceKm() : this.maxDistanceKm,
      minRating: minRating != null ? minRating() : this.minRating,
      maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  List<ServiceProvider> filterAndSort(List<ServiceProvider> source) {
    var results = source.where((pro) {
      // 1. Text Query (Search by service/trade, name, profession, businessName, location)
      if (query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final matchesName = pro.name.toLowerCase().contains(q);
        final matchesProfession = pro.profession.toLowerCase().contains(q);
        final matchesBusiness = pro.businessName.toLowerCase().contains(q);
        final matchesLocation = pro.location.toLowerCase().contains(q);
        final matchesCategory = pro.categoryId.toLowerCase().contains(q);

        if (!matchesName &&
            !matchesProfession &&
            !matchesBusiness &&
            !matchesLocation &&
            !matchesCategory) {
          return false;
        }
      }

      // 2. Category Filter
      if (categoryId != null && categoryId!.isNotEmpty) {
        if (pro.categoryId.toLowerCase() != categoryId!.toLowerCase()) {
          return false;
        }
      }

      // 3. Max Distance Filter
      if (maxDistanceKm != null) {
        if (pro.distanceKm > maxDistanceKm!) {
          return false;
        }
      }

      // 4. Min Rating Filter
      if (minRating != null) {
        if (pro.rating < minRating!) {
          return false;
        }
      }

      // 5. Max Price Filter
      if (maxPrice != null) {
        if (pro.startingPriceAmount == null || pro.startingPriceAmount! > maxPrice!) {
          return false;
        }
      }

      // 6. Verified Only Filter
      if (verifiedOnly && !pro.isVerified) {
        return false;
      }

      return true;
    }).toList();

    // Sorting
    switch (sortBy) {
      case SearchSortOption.recommended:
        // Default curated order (verified and rating weighted)
        break;
      case SearchSortOption.nearest:
        results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        break;
      case SearchSortOption.highestRated:
        results.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case SearchSortOption.priceLowToHigh:
        results.sort((a, b) {
          if (a.startingPriceAmount == null && b.startingPriceAmount == null) return 0;
          if (a.startingPriceAmount == null) return 1;
          if (b.startingPriceAmount == null) return -1;
          return a.startingPriceAmount!.compareTo(b.startingPriceAmount!);
        });
        break;
      case SearchSortOption.mostReviewed:
        results.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
        break;
    }

    return results;
  }
}
