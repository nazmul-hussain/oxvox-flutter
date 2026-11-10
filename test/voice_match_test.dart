import 'package:flutter_test/flutter_test.dart';
import 'package:oxvox/services/voice_answer.dart';

void main() {
  const opts = ['abandon', 'ability', 'absent', 'accept'];
  test('exact and inside phrase', () {
    expect(matchSpokenOption(['Abandon'], opts), 'abandon');
    expect(matchSpokenOption(["I think it's accept"], opts), 'accept');
  });
  test('position words', () {
    expect(matchSpokenOption(['three'], opts), 'absent');
    expect(matchSpokenOption(['option B'], opts), 'ability');
  });
  test('close spelling', () {
    expect(matchSpokenOption(['abilty'], opts), 'ability');
  });
  test('no confident match', () {
    expect(matchSpokenOption(['banana'], opts), isNull);
    expect(matchSpokenOption([], opts), isNull);
  });
  test('bangla', () {
    expect(
      matchSpokenOption(['ত্যাগ করা'], ['ত্যাগ করা', 'ক্ষমতা']),
      'ত্যাগ করা',
    );
  });
  test('one of several meanings', () {
    const bn = [
      'ত্যাগ করা, পরিত্যাগ',
      'ক্ষমতা; সামর্থ্য',
      'অনুপস্থিত',
      'গ্রহণ করা',
    ];
    expect(matchSpokenOption(['পরিত্যাগ'], bn), bn[0]);
    expect(matchSpokenOption(['সামর্থ্য'], bn), bn[1]);
    expect(matchSpokenOption(['গ্রহণ করা'], bn), bn[3]);
  });
}
