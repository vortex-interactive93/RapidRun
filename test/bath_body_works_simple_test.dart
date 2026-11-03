import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrun/models/product.dart';
import 'package:rapidrun/services/bbw_catalog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('BBWCatalogService loads enriched Bath & Body Works catalog', () async {
    final catalog = await BBWCatalogService.instance.loadCatalog();
    expect(catalog.isNotEmpty, true);
    
    final first = catalog.first;
    expect(first.id, startsWith('bbw_'));
    expect(first.name.isNotEmpty, true);
    expect(first.brand, 'Bath & Body Works');
    expect(first.category, 'Body Care');
    expect(first.price, greaterThan(0));
    expect(first.imageUrl, contains('sw=600'));

    // Check specific audited items for volume accuracy
    final rollerball = catalog.firstWhere((p) => p.id == 'bbw_028033845');
    expect(rollerball.unit, '0.23 fl oz / 7 mL');

    final deodorant = catalog.firstWhere((p) => p.id == 'bbw_028013160');
    expect(deodorant.unit, '2.7 oz / 76 g');

    final cologne = catalog.firstWhere((p) => p.id == 'bbw_028026575');
    expect(cologne.unit, '3.4 fl oz / 100 mL');

    final mist = catalog.firstWhere((p) => p.id == 'bbw_028005120');
    expect(mist.unit, '8 fl oz / 236 mL');
    expect(mist.description?.toLowerCase(), contains('pink prosecco'));
  });

  test('Loads enriched Bath & Body Works moisturizers catalog', () async {
    final raw = await rootBundle.loadString(
      'assets/stores/bath_and_body_works/body_care/moisturizers/moisturizers.json',
    );
    final List<dynamic> list = json.decode(raw);
    final products = list.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();

    expect(products.length, 127);

    final lotion = products.firstWhere((p) => p.id == 'bbw_028005118');
    expect(lotion.name, 'A Thousand Wishes Body Lotion');
    expect(lotion.unit, '8 fl oz / 236 mL');
    expect(lotion.price, 16.95);
    expect(lotion.rating, 4.8);
    expect(lotion.fragranceProfile?.topNotes, contains('Pink Prosecco'));

    final cream = products.firstWhere((p) => p.id == 'bbw_028005116');
    expect(cream.name, 'A Thousand Wishes Ultimate Hydration Body Cream');
    expect(cream.unit, '8 oz / 226 g');
    expect(cream.price, 17.95);
  });

  test('Loads enriched Bath & Body Works travel minis catalog', () async {
    final raw = await rootBundle.loadString(
      'assets/stores/bath_and_body_works/body_care/minis/travel_minis.json',
    );
    final List<dynamic> list = json.decode(raw);
    final products = list.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();

    expect(products.length, 55);

    final miniCream = products.firstWhere((p) => p.id == 'bbw_028005916');
    expect(miniCream.name, contains('Travel Size Ultimate Hydration Body Cream'));
    expect(miniCream.unit, '2.5 oz / 70 g');
    expect(miniCream.fragranceProfile?.topNotes, contains('Pink Prosecco'));

    final miniMist = products.firstWhere((p) => p.id == 'bbw_028016950');
    expect(miniMist.name, contains('Travel Size Fine Fragrance Mist'));
    expect(miniMist.unit, '2.5 fl oz / 75 mL');
    expect(miniMist.price, 8.95);
  });

  test('Loads enriched Bath & Body Works lip care catalog', () async {
    final raw = await rootBundle.loadString(
      'assets/stores/bath_and_body_works/body_care/skin_care/bbw_lip_care.json',
    );
    final List<dynamic> list = json.decode(raw);
    final products = list.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();

    expect(products.length, 19);

    final nightBalm = products.firstWhere((p) => p.id == 'bbw_026667303');
    expect(nightBalm.name, 'My Favorite Night Balm Lip Balm');
    expect(nightBalm.unit, '0.5 oz / 14 g');
    expect(nightBalm.price, 8.95);

    final peptide = products.firstWhere((p) => p.id == 'bbw_028031270');
    expect(peptide.name, 'Bare Blush Peptide Lip Advanced');
    expect(peptide.price, 14.95);

    final lipOil = products.firstWhere((p) => p.id == 'bbw_028030828');
    expect(lipOil.name, 'Vampire Blood Lip Oil');
    expect(lipOil.price, 12.95);
  });

  test('Loads enriched Bath & Body Works 3-wick candles catalog', () async {
    final raw = await rootBundle.loadString(
      'assets/stores/bath_and_body_works/candles/bbw_3_wick_candles.json',
    );
    final List<dynamic> list = json.decode(raw);
    final products = list.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();

    expect(products.length, 65);

    final iceCream = products.firstWhere((p) => p.id == 'bbw_028030716');
    expect(iceCream.name, 'Neapolitan Ice Cream 3-Wick Candle');
    expect(iceCream.unit, '14.5 oz / 411 g');
    expect(iceCream.price, 24.95);
    expect(iceCream.cleanStandards, contains('25–45 Hour Burn Time'));
    expect(iceCream.fragranceProfile?.topNotes, contains('Rich Chocolate'));

    final champagne = products.firstWhere((p) => p.id == 'bbw_028029548');
    expect(champagne.name, 'Champagne Toast 3-Wick Candle');
    expect(champagne.price, 24.95);
  });

  test('Loads enriched Bath & Body Works 4-wick candles catalog', () async {
    final raw = await rootBundle.loadString(
      'assets/stores/bath_and_body_works/candles/bbw_4_wick_candles.json',
    );
    final List<dynamic> list = json.decode(raw);
    final products = list.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();

    expect(products.length, 5);

    final santalAmber = products.firstWhere((p) => p.id == 'bbw_028030788');
    expect(santalAmber.name, 'Santal + Amber 4-Wick Candle');
    expect(santalAmber.unit, '18 oz / 510 g');
    expect(santalAmber.price, 32.95);
    expect(santalAmber.cleanStandards, contains('4 Lead-Free Wicks'));
    expect(santalAmber.fragranceProfile?.topNotes, contains('Creamy Santal'));
  });

  test('Loads enriched Bath & Body Works single-wick candles catalog', () async {
    final raw = await rootBundle.loadString(
      'assets/stores/bath_and_body_works/candles/bbw_single_wick_candles.json',
    );
    final List<dynamic> list = json.decode(raw);
    final products = list.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();

    expect(products.length, 36);

    final champagne = products.firstWhere((p) => p.id == 'bbw_028017847');
    expect(champagne.name, 'Champagne Toast Single Wick Candle');
    expect(champagne.unit, '8 oz / 227 g');
    expect(champagne.price, 16.95);
    expect(champagne.rating, 4.7);
    expect(champagne.cleanStandards, contains('Lead-Free Wick'));
    expect(champagne.fragranceProfile?.topNotes, contains('Vintage Champagne'));
  });

  test('Loads enriched Bath & Body Works wallflower refills catalog', () async {
    final raw = await rootBundle.loadString(
      'assets/stores/bath_and_body_works/wallflowers_diffusers/bbw_wallflower_refill.json',
    );
    final List<dynamic> list = json.decode(raw);
    final products = list.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();

    expect(products.length, 46);

    final laundryDay = products.firstWhere((p) => p.id == 'bbw_028008664');
    expect(laundryDay.name, 'Laundry Day Wallflowers Fragrance Refill');
    expect(laundryDay.unit, '0.8 fl oz / 24 mL');
    expect(laundryDay.price, 7.95);
    expect(laundryDay.rating, 4.7);
    expect(laundryDay.cleanStandards, contains('Up to 30 Days Continuous Scent'));
    expect(laundryDay.fragranceProfile?.topNotes, contains('Fresh Wash'));
  });

  test('Loads enriched Bath & Body Works wallflower plugs catalog', () async {
    final raw = await rootBundle.loadString(
      'assets/stores/bath_and_body_works/wallflowers_diffusers/bbw_wallflower_plugs.json',
    );
    final List<dynamic> list = json.decode(raw);
    final products = list.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();

    expect(products.length, 36);

    final whiteFlare = products.firstWhere((p) => p.id == 'bbw_026634611');
    expect(whiteFlare.name, 'White Flare Wallflowers Fragrance Plug');
    expect(whiteFlare.unit, '1 ct');
    expect(whiteFlare.price, 5.95);
    expect(whiteFlare.rating, 4.3);
    expect(whiteFlare.cleanStandards, contains('Pairs With All Wallflowers Bulbs'));
  });

  test('Loads enriched Bath & Body Works hand soaps and sanitizers catalogs', () async {
    final rawFoaming = await rootBundle.loadString(
      'assets/stores/bath_and_body_works/hand_soaps_sanitizers/bbw_foaming_soaps.json',
    );
    final List<dynamic> listFoaming = json.decode(rawFoaming);
    final foamingProducts = listFoaming.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();
    expect(foamingProducts.length, 21);

    final champagneSoap = foamingProducts.firstWhere((p) => p.id == 'bbw_028003595');
    expect(champagneSoap.name, 'Champagne Toast Gentle & Clean Foaming Hand Soap');
    expect(champagneSoap.unit, '8.75 fl oz / 258 mL');
    expect(champagneSoap.price, 7.95);
    expect(champagneSoap.rating, 4.9);

    final rawSanitizers = await rootBundle.loadString(
      'assets/stores/bath_and_body_works/hand_soaps_sanitizers/bbw_hand_sanitizers.json',
    );
    final List<dynamic> listSanitizers = json.decode(rawSanitizers);
    final sanitizerProducts = listSanitizers.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();
    expect(sanitizerProducts.length, 67);

    final pocketbac = sanitizerProducts.firstWhere((p) => p.id == 'bbw_028004878');
    expect(pocketbac.name, 'Champagne Toast PocketBac Hand Sanitizer');
    expect(pocketbac.unit, '1 fl oz / 29 mL');
    expect(pocketbac.price, 1.95);
  });

  test('Loads enriched Bath & Body Works bath and shower catalog', () async {
    final raw = await rootBundle.loadString(
      'assets/stores/bath_and_body_works/body_care/bath_shower/bbw_body_wash.json',
    );
    final List<dynamic> list = json.decode(raw);
    final products = list.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();

    expect(products.isNotEmpty, true);

    final wish = products.firstWhere((p) => p.id == 'bbw_028005920');
    expect(wish.name, 'A Thousand Wishes Travel Size Body Wash');
    expect(wish.unit, '2.5 fl oz / 75 mL');
    expect(wish.price, 8.95);
  });

  test('Loads enriched Bath & Body Works mens shop catalogs', () async {
    final rawFragrance = await rootBundle.loadString(
      'assets/stores/bath_and_body_works/mens_shop/bbw_mens_fragrance.json',
    );
    final List<dynamic> listFragrance = json.decode(rawFragrance);
    final fragranceProducts = listFragrance.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();
    expect(fragranceProducts.length, 10);

    final miniCologne = fragranceProducts.firstWhere((p) => p.id == 'bbw_028013178');
    expect(miniCologne.name, 'Mahogany Teakwood Mini Cologne');
    expect(miniCologne.unit, '0.5 fl oz / 15 mL');
    expect(miniCologne.price, 17.95);
    expect(miniCologne.rating, 4.7);

    final rawWash = await rootBundle.loadString(
      'assets/stores/bath_and_body_works/mens_shop/bbw_mens_body_wash.json',
    );
    final List<dynamic> listWash = json.decode(rawWash);
    final washProducts = listWash.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();
    expect(washProducts.length, 11);

    final wash = washProducts.firstWhere((p) => p.id == 'bbw_028013138');
    expect(wash.name, 'Mahogany Teakwood 3-in-1 Hair, Face & Body Wash');
    expect(wash.unit, '10 fl oz / 295 mL');
    expect(wash.price, 15.95);
  });
}
