import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:intl/intl.dart';

import 'deal_calc.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DealCalc Mobile',
      theme: ThemeData(
        primarySwatch: Colors.green,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  StreamSubscription? _intentDataStreamSubscription;
  String _sharedText = "";
  DealResult? _dealResult;

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // Tax settings state
  bool _taxEnabled = false;
  String _taxType = 'exclude';
  double _taxPpn = 11.0;
  double _taxPph = 0.0;
  
  late TextEditingController _ppnController;
  late TextEditingController _pphController;

  @override
  void initState() {
    super.initState();
    _ppnController = TextEditingController(text: _taxPpn.toString());
    _pphController = TextEditingController(text: _taxPph.toString());

    // App is running in background and receives intent
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _processSharedText(value.first.path);
      }
    }, onError: (err) {
      print("getLinkStream error: $err");
    });

    // App was closed and opened via intent
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _processSharedText(value.first.path);
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  void _processSharedText(String text) {
    setState(() {
      _sharedText = text;
      _dealResult = DealCalc.parseText(
        text,
        taxEnabled: _taxEnabled,
        taxType: _taxType,
        ppnRate: _taxPpn,
        pphRate: _taxPph,
      );
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    _ppnController.dispose();
    _pphController.dispose();
    super.dispose();
  }

  void _copyToClipboard() {
    if (_dealResult == null) return;
    final r = _dealResult!;
    
    final StringBuffer sb = StringBuffer();
    sb.writeln("=== DEAL SUMMARY ===");
    sb.writeln("Qty x Harga: ${r.qty.toInt()} pcs x ${_currencyFormat.format(r.price)}");
    
    if (r.isTaxEnabled) {
      if (r.taxType == 'exclude') {
        sb.writeln("Subtotal: ${_currencyFormat.format(r.originalSubtotal)}");
      }
      if (r.ppnAmount > 0) {
        String includeStr = r.taxType == 'include' ? " (Include)" : "";
        sb.writeln("🏛️ PPN (${r.ppnRate}%): +${_currencyFormat.format(r.ppnAmount)}$includeStr");
      }
      if (r.pphAmount > 0) {
        sb.writeln("🏛️ PPH (${r.pphRate}%): -${_currencyFormat.format(r.pphAmount)}");
      }
      if (r.taxType == 'include' && r.ppnAmount > 0) {
        sb.writeln("Harga Dasar (Stlh Pajak): ${_currencyFormat.format(r.baseAfterTax)}");
      }
    } else {
      sb.writeln("Subtotal: ${_currencyFormat.format(r.originalSubtotal)}");
    }

    if (r.discountPercentages.isNotEmpty) {
      sb.writeln("---");
      sb.writeln("Pembagian Diskon:");
      for (int i = 0; i < r.discountPercentages.length; i++) {
        sb.writeln("  🔻 Diskon ${i+1} (${r.discountPercentages[i]}%): -${_currencyFormat.format(r.discountAmounts[i])}");
      }
      sb.writeln("  🔻 Total Diskon: -${_currencyFormat.format(r.totalDiscount)}");
    }
    
    if (r.shippingCost > 0) {
      sb.writeln("---");
      sb.writeln("🚚 Ongkir: +${_currencyFormat.format(r.shippingCost)}");
    }

    sb.writeln("---");
    sb.writeln("💰 TOTAL BERSIH: ${_currencyFormat.format(r.finalTotal)}");
    sb.writeln("🏷️ Harga per pcs: ${_currencyFormat.format(r.pricePerPcs)}");

    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tersalin ke clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DealCalc'),
        backgroundColor: const Color(0xFF25D366),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_sharedText.isNotEmpty) ...[
              const Text("Shared Text:", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade800)
                ),
                child: Text(_sharedText, style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
              
              // TAX UI OPTIONS
              Card(
                color: const Color(0xFF2A2A2A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Kalkulasi Pajak", style: TextStyle(fontWeight: FontWeight.bold)),
                          Switch(
                            value: _taxEnabled,
                            activeColor: Colors.greenAccent,
                            onChanged: (val) {
                              setState(() {
                                _taxEnabled = val;
                                if (_sharedText.isNotEmpty) _processSharedText(_sharedText);
                              });
                            },
                          ),
                        ],
                      ),
                      if (_taxEnabled)
                        Row(
                          children: [
                            DropdownButton<String>(
                              value: _taxType,
                              dropdownColor: const Color(0xFF2A2A2A),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: const [
                                DropdownMenuItem(value: 'exclude', child: Text('Exclude')),
                                DropdownMenuItem(value: 'include', child: Text('Include')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _taxType = val;
                                    if (_sharedText.isNotEmpty) _processSharedText(_sharedText);
                                  });
                                }
                              },
                            ),
                            const Spacer(),
                            const Text("PPN% ", style: TextStyle(fontSize: 12)),
                            SizedBox(
                              width: 40,
                              child: TextField(
                                controller: _ppnController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13),
                                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(4)),
                                onChanged: (val) {
                                  _taxPpn = double.tryParse(val) ?? 0;
                                  if (_sharedText.isNotEmpty) _processSharedText(_sharedText);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text("PPH% ", style: TextStyle(fontSize: 12)),
                            SizedBox(
                              width: 40,
                              child: TextField(
                                controller: _pphController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13),
                                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(4)),
                                onChanged: (val) {
                                  _taxPph = double.tryParse(val) ?? 0;
                                  if (_sharedText.isNotEmpty) _processSharedText(_sharedText);
                                },
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              const Expanded(
                child: Center(
                  child: Text("Silakan Share teks negosiasi dari WhatsApp ke aplikasi ini.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16)
                  ),
                ),
              ),
            ],

            if (_dealResult != null) ...[
              const Text("Hasil Kalkulasi:", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Card(
                    color: const Color(0xFF2A2A2A),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(child: Text("Qty x Harga")),
                              Text("${_dealResult!.qty.toInt()} x ${_currencyFormat.format(_dealResult!.price)}", textAlign: TextAlign.right),
                            ],
                          ),
                          
                          if (!_dealResult!.isTaxEnabled || _dealResult!.taxType == 'exclude') ...[
                            const Divider(color: Colors.grey),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Expanded(child: Text("Subtotal")),
                                Text(_currencyFormat.format(_dealResult!.originalSubtotal), textAlign: TextAlign.right),
                              ],
                            ),
                          ],
                          
                          if (_dealResult!.isTaxEnabled) ...[
                            if (_dealResult!.ppnAmount > 0) ...[
                              const Divider(color: Colors.grey),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: Text("🏛️ PPN (${_dealResult!.ppnRate}%)", style: const TextStyle(color: Colors.tealAccent))),
                                  Text("+${_currencyFormat.format(_dealResult!.ppnAmount)}", style: const TextStyle(color: Colors.tealAccent), textAlign: TextAlign.right),
                                ],
                              ),
                            ],
                            if (_dealResult!.pphAmount > 0) ...[
                              const Divider(color: Colors.grey),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: Text("🏛️ PPH (${_dealResult!.pphRate}%)", style: const TextStyle(color: Colors.tealAccent))),
                                  Text("-${_currencyFormat.format(_dealResult!.pphAmount)}", style: const TextStyle(color: Colors.tealAccent), textAlign: TextAlign.right),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Expanded(child: Text("Harga Dasar (Stlh Pajak)", style: TextStyle(color: Colors.white70))),
                                Text(_currencyFormat.format(_dealResult!.baseAfterTax), style: const TextStyle(color: Colors.white70), textAlign: TextAlign.right),
                              ],
                            ),
                          ],

                          if (_dealResult!.discountPercentages.isNotEmpty) ...[
                            const Divider(color: Colors.grey),
                            const Text("Pembagian Diskon:", style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 4),
                            for (int i = 0; i < _dealResult!.discountPercentages.length; i++)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: Text("  🔻 Diskon ${i+1} (${_dealResult!.discountPercentages[i]}%)", style: const TextStyle(color: Colors.redAccent))),
                                  Text("-${_currencyFormat.format(_dealResult!.discountAmounts[i])}", style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.right),
                                ],
                              ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Expanded(child: Text("  🔻 Total Diskon", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                                Text("-${_currencyFormat.format(_dealResult!.totalDiscount)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                              ],
                            ),
                          ],
                          
                          if (_dealResult!.shippingCost > 0) ...[
                            const Divider(color: Colors.grey),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Expanded(child: Text("🚚 Ongkir", style: TextStyle(color: Colors.orangeAccent))),
                                Text("+${_currencyFormat.format(_dealResult!.shippingCost)}", style: const TextStyle(color: Colors.orangeAccent), textAlign: TextAlign.right),
                              ],
                            ),
                          ],
                          
                          const Divider(color: Colors.grey, thickness: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(child: Text("TOTAL BERSIH", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.greenAccent))),
                              Text(
                                _currencyFormat.format(_dealResult!.finalTotal), 
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                                textAlign: TextAlign.right,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(child: Text("🏷️ Harga per pcs", style: TextStyle(color: Colors.grey))),
                              Text(_currencyFormat.format(_dealResult!.pricePerPcs), style: const TextStyle(color: Colors.grey), textAlign: TextAlign.right),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _copyToClipboard,
                icon: const Icon(Icons.copy),
                label: const Text("SALIN HASIL"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}
