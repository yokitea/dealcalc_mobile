class DealResult {
  final double qty;
  final double price;
  final double originalSubtotal;
  final List<double> discountPercentages;
  final List<double> discountAmounts;
  final double totalDiscount;
  final double shippingCost;

  final bool isTaxEnabled;
  final String taxType;
  final double ppnRate;
  final double ppnAmount;
  final double pphRate;
  final double pphAmount;
  final double baseAfterTax;

  final double finalTotal;
  final double pricePerPcs;
  final String rawText;

  DealResult({
    required this.qty,
    required this.price,
    required this.originalSubtotal,
    required this.discountPercentages,
    required this.discountAmounts,
    required this.totalDiscount,
    required this.shippingCost,
    required this.isTaxEnabled,
    required this.taxType,
    required this.ppnRate,
    required this.ppnAmount,
    required this.pphRate,
    required this.pphAmount,
    required this.baseAfterTax,
    required this.finalTotal,
    required this.pricePerPcs,
    required this.rawText,
  });
}

class DealCalc {
  static final RegExp dealRegex = RegExp(
      r'([\d.,]+)\s*(pcs|x)\s*([\d.,]+)([a-zA-Z]*)(?:\s*(?:diskon|-)\s*([\d.,]+%?(?:\s*\+\s*[\d.,]+%?)*))?(?:\s*(?:ongkir|ongkos kirim)\s*([\d.,]+)([a-zA-Z]*))?',
      caseSensitive: false);

  static DealResult? parseText(
    String text, {
    bool taxEnabled = false,
    String taxType = 'exclude',
    double ppnRate = 11.0,
    double pphRate = 0.0,
  }) {
    final match = dealRegex.firstMatch(text);
    if (match == null) return null;

    final String qtyStr = match.group(1) ?? '1';
    final String priceStr = match.group(3) ?? '0';
    final String suffix = (match.group(4) ?? '').toLowerCase().trim();
    final String discountsStr = match.group(5) ?? '';
    final String shippingStr = match.group(6) ?? '0';
    final String shippingSuffix = (match.group(7) ?? '').toLowerCase().trim();

    double qty = _parseDouble(qtyStr);
    double basePrice = _parseDouble(priceStr);

    if (suffix == 'k' || suffix == 'rb' || suffix == 'ribu') {
      basePrice *= 1000;
    } else if (suffix == 'jt' || suffix == 'juta') {
      basePrice *= 1000000;
    } else if (suffix == 'm') {
      basePrice *= 1000000000;
    }

    double shippingCost = _parseDouble(shippingStr);
    if (shippingSuffix == 'k' || shippingSuffix == 'rb' || shippingSuffix == 'ribu') {
      shippingCost *= 1000;
    } else if (shippingSuffix == 'jt' || shippingSuffix == 'juta') {
      shippingCost *= 1000000;
    } else if (shippingSuffix == 'm') {
      shippingCost *= 1000000000;
    }

    double originalSubtotal = qty * basePrice;

    double baseAfterTax = originalSubtotal;
    double ppnAmount = 0;
    double pphAmount = 0;

    if (taxEnabled) {
      if (taxType == 'include') {
        // As per directive, if Include, we apply the exact math they asked or keep Akuntansi?
        // Wait, the user said "Harga - (PPN+PPH) = Harga setelah potong pajak".
        // Let's use exactly that.
        double ppnFraction = ppnRate / 100.0;
        double pphFraction = pphRate / 100.0;
        // If Include, PPN and PPH are calculated from what? 
        // If they want Akuntansi:
        baseAfterTax = originalSubtotal / (1 + ppnFraction);
        ppnAmount = originalSubtotal - baseAfterTax;
        pphAmount = baseAfterTax * pphFraction;
        baseAfterTax = baseAfterTax - pphAmount;
        // Wait, if I do this, it is exactly Harga - PPN - PPH.
      } else {
        // Exclude
        double ppnFraction = ppnRate / 100.0;
        double pphFraction = pphRate / 100.0;
        ppnAmount = originalSubtotal * ppnFraction;
        pphAmount = originalSubtotal * pphFraction;
        // User directive: Harga - (PPN+PPH) = Harga setelah potong pajak
        baseAfterTax = originalSubtotal - ppnAmount - pphAmount; 
      }
    }

    List<double> discountPercentages = [];
    if (discountsStr.isNotEmpty) {
      final parts = discountsStr.split('+');
      for (var part in parts.take(3)) {
        String cleanPart = part.replaceAll('%', '').trim();
        double? d = double.tryParse(cleanPart.replaceAll(',', '.'));
        if (d != null) {
          discountPercentages.add(d);
        }
      }
    }

    List<double> discountAmounts = [];
    double totalDiscount = 0;
    
    for (double pct in discountPercentages) {
      double amount = baseAfterTax * (pct / 100.0);
      discountAmounts.add(amount);
      totalDiscount += amount;
    }

    double finalTotal = originalSubtotal;
    if (taxEnabled) {
      if (taxType == 'include') {
        finalTotal = originalSubtotal - totalDiscount - pphAmount + shippingCost;
      } else {
        finalTotal = originalSubtotal - totalDiscount + ppnAmount - pphAmount + shippingCost;
      }
    } else {
      finalTotal = originalSubtotal - totalDiscount + shippingCost;
    }

    double pricePerPcs = qty > 0 ? (finalTotal / qty) : 0;

    return DealResult(
      qty: qty,
      price: basePrice,
      originalSubtotal: originalSubtotal,
      discountPercentages: discountPercentages,
      discountAmounts: discountAmounts,
      totalDiscount: totalDiscount,
      shippingCost: shippingCost,
      isTaxEnabled: taxEnabled,
      taxType: taxType,
      ppnRate: ppnRate,
      ppnAmount: ppnAmount,
      pphRate: pphRate,
      pphAmount: pphAmount,
      baseAfterTax: baseAfterTax,
      finalTotal: finalTotal,
      pricePerPcs: pricePerPcs,
      rawText: match.group(0) ?? text,
    );
  }

  static double _parseDouble(String val) {
    String clean = val.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(clean) ?? 0;
  }
}
