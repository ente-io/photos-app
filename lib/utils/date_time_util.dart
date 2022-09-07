// @dart=2.9

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Map<int, String> _months = {
  1: "Jan",
  2: "Feb",
  3: "March",
  4: "April",
  5: "May",
  6: "Jun",
  7: "July",
  8: "Aug",
  9: "Sep",
  10: "Oct",
  11: "Nov",
  12: "Dec",
};

Map<int, String> _fullMonths = {
  1: "January",
  2: "February",
  3: "March",
  4: "April",
  5: "May",
  6: "June",
  7: "July",
  8: "August",
  9: "September",
  10: "October",
  11: "November",
  12: "December",
};

Map<int, String> _days = {
  1: "Mon",
  2: "Tue",
  3: "Wed",
  4: "Thu",
  5: "Fri",
  6: "Sat",
  7: "Sun",
};

final currentYear = int.parse(DateTime.now().year.toString());

//Jun 2022
String getMonthAndYear(DateTime dateTime) {
  return _months[dateTime.month] + " " + dateTime.year.toString();
}

//Thu, 30 Jun
String getDayAndMonth(DateTime dateTime) {
  return _days[dateTime.weekday] +
      ", " +
      dateTime.day.toString() +
      " " +
      _months[dateTime.month];
}

//30 Jun, 2022
String getDateAndMonthAndYear(DateTime dateTime) {
  return dateTime.day.toString() +
      " " +
      _months[dateTime.month] +
      ", " +
      dateTime.year.toString();
}

String getDay(DateTime dateTime) {
  return _days[dateTime.weekday];
}

String getMonth(DateTime dateTime) {
  return _months[dateTime.month];
}

String getFullMonth(DateTime dateTime) {
  return _fullMonths[dateTime.month];
}

String getAbbreviationOfYear(DateTime dateTime) {
  return (dateTime.year % 100).toString();
}

//14:32
String getTime(DateTime dateTime) {
  final hours = dateTime.hour > 9
      ? dateTime.hour.toString()
      : "0" + dateTime.hour.toString();
  final minutes = dateTime.minute > 9
      ? dateTime.minute.toString()
      : "0" + dateTime.minute.toString();
  return hours + ":" + minutes;
}

//11:22 AM
String getTimeIn12hrFormat(DateTime dateTime) {
  return DateFormat.jm().format(dateTime);
}

//Thu, Jun 30, 2022 - 14:32
String getFormattedTime(DateTime dateTime) {
  return getDay(dateTime) +
      ", " +
      getMonth(dateTime) +
      " " +
      dateTime.day.toString() +
      ", " +
      dateTime.year.toString() +
      " - " +
      getTime(dateTime);
}

//30 Jun'22
String getFormattedDate(DateTime dateTime) {
  return dateTime.day.toString() +
      " " +
      getMonth(dateTime) +
      "'" +
      getAbbreviationOfYear(dateTime);
}

String getFullDate(DateTime dateTime) {
  return getDay(dateTime) +
      ", " +
      getMonth(dateTime) +
      " " +
      dateTime.day.toString() +
      " " +
      dateTime.year.toString();
}

String daysLeft(int futureTime) {
  final int daysLeft = ((futureTime - DateTime.now().microsecondsSinceEpoch) /
          Duration.microsecondsPerDay)
      .ceil();
  return '$daysLeft day' + (daysLeft <= 1 ? "" : "s");
}

String formatDuration(Duration position) {
  final ms = position.inMilliseconds;

  int seconds = ms ~/ 1000;
  final int hours = seconds ~/ 3600;
  seconds = seconds % 3600;
  final minutes = seconds ~/ 60;
  seconds = seconds % 60;

  final hoursString = hours >= 10
      ? '$hours'
      : hours == 0
          ? '00'
          : '0$hours';

  final minutesString = minutes >= 10
      ? '$minutes'
      : minutes == 0
          ? '00'
          : '0$minutes';

  final secondsString = seconds >= 10
      ? '$seconds'
      : seconds == 0
          ? '00'
          : '0$seconds';

  final formattedTime =
      '${hoursString == '00' ? '' : hoursString + ':'}$minutesString:$secondsString';

  return formattedTime;
}

bool isLeapYear(DateTime dateTime) {
  final year = dateTime.year;
  if (year % 4 == 0) {
    if (year % 100 == 0) {
      if (year % 400 == 0) {
        return true;
      } else {
        return false;
      }
    } else {
      return true;
    }
  } else {
    return false;
  }
}

Widget getDayWidget(
  BuildContext context,
  int timestamp,
  bool smallerTodayFont,
) {
  return Container(
    padding: const EdgeInsets.fromLTRB(4, 14, 0, 8),
    alignment: Alignment.centerLeft,
    child: Text(
      getDayTitle(timestamp),
      style: (getDayTitle(timestamp) == "Today" && !smallerTodayFont)
          ? Theme.of(context).textTheme.headline5
          : Theme.of(context).textTheme.caption.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter-SemiBold',
              ),
    ),
  );
}

String getDayTitle(int timestamp) {
  final date = DateTime.fromMicrosecondsSinceEpoch(timestamp);
  final now = DateTime.now();
  var title = getDayAndMonth(date);
  if (date.year == now.year && date.month == now.month) {
    if (date.day == now.day) {
      title = "Today";
    } else if (date.day == now.day - 1) {
      title = "Yesterday";
    }
  }
  if (date.year != DateTime.now().year) {
    title += " " + date.year.toString();
  }
  return title;
}

String secondsToHHMMSS(int value) {
  int h, m, s;
  h = value ~/ 3600;
  m = ((value - h * 3600)) ~/ 60;
  s = value - (h * 3600) - (m * 60);
  final String hourLeft = h.toString().length < 2 ? "0" + h.toString() : h.toString();

  final String minuteLeft =
      m.toString().length < 2 ? "0" + m.toString() : m.toString();

  final String secondsLeft =
      s.toString().length < 2 ? "0" + s.toString() : s.toString();

  final String result = "$hourLeft:$minuteLeft:$secondsLeft";

  return result;
}
