import 'package:flutter/material.dart';
import 'package:hello_nitr/core/constants/app_colors.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final double fontSize;

  SectionTitle(this.title, this.fontSize);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          SizedBox(width: 8.0),
          Text(
            title,
            style: TextStyle(
              color: AppColors.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
              fontFamily: 'Roboto',
            ),
          ),
          SizedBox(width: 8.0),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
    );
  }
}
