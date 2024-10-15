import 'package:flutter/material.dart';

class Item {
  final String name;
  final double price;
  final int reviewCount;
  final String image;

  Item({
    required this.name,
    required this.price,
    required this.reviewCount,
    required this.image,
  });
}

List<Item> itemList = [
  Item(
    name: 'BLUEBERRY',
    price: 5.66,
    reviewCount: 433,
    image: 'assets/images/blueberry.png',
  ),
  Item(
    name: 'ORANGE',
    price: 8.82,
    reviewCount: 200,
    image: 'assets/images/orange.png',
  ),
  Item(
    name: 'APPLE',
    price: 4.99,
    reviewCount: 350,
    image: 'assets/images/apple.png',
  ),
  Item(
    name: 'BANANA',
    price: 3.45,
    reviewCount: 150,
    image: 'assets/images/banana.png',
  ),
  Item(
    name: 'STRAWBERRY',
    price: 6.75,
    reviewCount: 275,
    image: 'assets/images/strawberry.png',
  ),
  Item(
    name: 'GRAPEFRUIT',
    price: 7.10,
    reviewCount: 120,
    image: 'assets/images/grapefruit.png',
  ),
  Item(
    name: 'MANGO',
    price: 9.99,
    reviewCount: 400,
    image: 'assets/images/mango.png',
  ),
  Item(
    name: 'PINEAPPLE',
    price: 12.50,
    reviewCount: 190,
    image: 'assets/images/pineapple.png',
  ),
  Item(
    name: 'KIWI',
    price: 5.20,
    reviewCount: 300,
    image: 'assets/images/kiwi.png',
  ),
  Item(
    name: 'PEACH',
    price: 7.75,
    reviewCount: 160,
    image: 'assets/images/peach.png',
  ),
  Item(
    name: 'PLUM',
    price: 6.00,
    reviewCount: 180,
    image: 'assets/images/plum.png',
  ),
  Item(
    name: 'CHERRY',
    price: 8.45,
    reviewCount: 220,
    image: 'assets/images/cherry.png',
  ),
  Item(
    name: 'WATERMELON',
    price: 15.00,
    reviewCount: 130,
    image: 'assets/images/watermelon.png',
  ),
  Item(
    name: 'LEMON',
    price: 4.25,
    reviewCount: 140,
    image: 'assets/images/lemon.png',
  ),
];

Color mainColor = const Color(0XFFF4C750);
Color primaryColor = const Color.fromARGB(255, 39, 39, 39);
Color secondaryColor = const Color.fromARGB(255, 111, 240, 5);
Color textColor =
    const Color.fromARGB(255, 252, 44, 252); // Renamed tColor to textColor
Color textColor2 =
    const Color.fromARGB(255, 18, 238, 154); // Renamed tColor to textColor
Color textColor3 =
    const Color.fromARGB(255, 226, 233, 230); // Renamed tColor to textColor
Color iconBackgroundColor =
    const Color(0XFF262626); // Renamed iconBack to iconBackgroundColor

class IconDetail {
  final String image;
  final String head;

  IconDetail({
    required this.image,
    required this.head,
  });
}

List<IconDetail> iconsList = [
  IconDetail(image: 'assets/icons/LikeOutline.svg', head: 'Quality\nAssurance'),
  IconDetail(image: 'assets/icons/StarOutline.svg', head: 'Highly\nRated'),
  IconDetail(image: 'assets/icons/SpoonOutline.svg', head: 'Best In\nTaste'),
  IconDetail(
      image: 'assets/icons/FreshOutline.svg', head: 'Freshness\nGuaranteed'),
  IconDetail(image: 'assets/icons/LocalOutline.svg', head: 'Locally\nSourced'),
  IconDetail(image: 'assets/icons/OrganicOutline.svg', head: 'Organic\nChoice'),
  IconDetail(image: 'assets/icons/HealthOutline.svg', head: 'Health\nBenefits'),
  IconDetail(
      image: 'assets/icons/DiscountOutline.svg', head: 'Great\nDiscounts'),
  IconDetail(
      image: 'assets/icons/SeasonalOutline.svg', head: 'Seasonal\nFavorites'),
  IconDetail(image: 'assets/icons/GreenOutline.svg', head: 'Eco-Friendly'),
  IconDetail(image: 'assets/icons/SuperfoodOutline.svg', head: 'Superfoods'),
];
