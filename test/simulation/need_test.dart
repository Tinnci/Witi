import 'package:flutter_test/flutter_test.dart';
import 'package:sims_like_game/simulation/need.dart';

void main() {
  group('Need', () {
    group('constructor', () {
      test('creates need with valid parameters', () {
        final need = Need(
          type: 'hunger',
          value: 80.0,
          decayRate: 1.5,
        );
        
        expect(need.type, equals('hunger'));
        expect(need.value, equals(80.0));
        expect(need.decayRate, equals(1.5));
      });
      
      test('throws assertion error for invalid value range', () {
        expect(
          () => Need(type: 'hunger', value: -10.0, decayRate: 1.0),
          throwsA(isA<AssertionError>()),
        );
        
        expect(
          () => Need(type: 'hunger', value: 150.0, decayRate: 1.0),
          throwsA(isA<AssertionError>()),
        );
      });
      
      test('throws assertion error for negative decay rate', () {
        expect(
          () => Need(type: 'hunger', value: 50.0, decayRate: -1.0),
          throwsA(isA<AssertionError>()),
        );
      });
    });
    
    group('decay', () {
      test('decreases value based on decay rate and time', () {
        final need = Need(type: 'hunger', value: 100.0, decayRate: 2.0);
        
        need.decay(5.0); // 5 seconds
        
        expect(need.value, equals(90.0)); // 100 - (2.0 * 5.0)
      });
      
      test('clamps value to minimum of 0.0', () {
        final need = Need(type: 'hunger', value: 5.0, decayRate: 2.0);
        
        need.decay(10.0); // Would result in -15.0
        
        expect(need.value, equals(0.0));
      });
      
      test('handles zero delta time', () {
        final need = Need(type: 'hunger', value: 50.0, decayRate: 2.0);
        final originalValue = need.value;
        
        need.decay(0.0);
        
        expect(need.value, equals(originalValue));
      });
      
      test('throws assertion error for negative delta time', () {
        final need = Need(type: 'hunger', value: 50.0, decayRate: 2.0);
        
        expect(
          () => need.decay(-1.0),
          throwsA(isA<AssertionError>()),
        );
      });
      
      test('handles fractional decay correctly', () {
        final need = Need(type: 'hunger', value: 100.0, decayRate: 1.5);
        
        need.decay(2.5); // 2.5 seconds
        
        expect(need.value, equals(96.25)); // 100 - (1.5 * 2.5)
      });
    });
    
    group('isCritical', () {
      test('returns true when value is below critical threshold', () {
        final need = Need(type: 'hunger', value: 15.0, decayRate: 1.0);
        
        expect(need.isCritical, isTrue);
      });
      
      test('returns false when value is at critical threshold', () {
        final need = Need(type: 'hunger', value: 20.0, decayRate: 1.0);
        
        expect(need.isCritical, isFalse);
      });
      
      test('returns false when value is above critical threshold', () {
        final need = Need(type: 'hunger', value: 25.0, decayRate: 1.0);
        
        expect(need.isCritical, isFalse);
      });
      
      test('updates correctly after decay', () {
        final need = Need(type: 'hunger', value: 25.0, decayRate: 2.0);
        
        expect(need.isCritical, isFalse);
        
        need.decay(3.0); // Value becomes 19.0
        
        expect(need.isCritical, isTrue);
      });
    });
    
    group('deficit', () {
      test('calculates correct deficit for partially satisfied need', () {
        final need = Need(type: 'hunger', value: 70.0, decayRate: 1.0);
        
        expect(need.deficit, equals(30.0)); // 100.0 - 70.0
      });
      
      test('returns 0 for fully satisfied need', () {
        final need = Need(type: 'hunger', value: 100.0, decayRate: 1.0);
        
        expect(need.deficit, equals(0.0));
      });
      
      test('returns 100 for completely depleted need', () {
        final need = Need(type: 'hunger', value: 0.0, decayRate: 1.0);
        
        expect(need.deficit, equals(100.0));
      });
    });
    
    group('satisfactionPercentage', () {
      test('calculates correct percentage for various values', () {
        expect(
          Need(type: 'hunger', value: 0.0, decayRate: 1.0).satisfactionPercentage,
          equals(0.0),
        );
        
        expect(
          Need(type: 'hunger', value: 50.0, decayRate: 1.0).satisfactionPercentage,
          equals(0.5),
        );
        
        expect(
          Need(type: 'hunger', value: 100.0, decayRate: 1.0).satisfactionPercentage,
          equals(1.0),
        );
      });
    });
    
    group('satisfy', () {
      test('increases value by specified amount', () {
        final need = Need(type: 'hunger', value: 30.0, decayRate: 1.0);
        
        need.satisfy(20.0);
        
        expect(need.value, equals(50.0));
      });
      
      test('clamps value to maximum of 100.0', () {
        final need = Need(type: 'hunger', value: 90.0, decayRate: 1.0);
        
        need.satisfy(20.0); // Would result in 110.0
        
        expect(need.value, equals(100.0));
      });
      
      test('throws assertion error for negative amount', () {
        final need = Need(type: 'hunger', value: 50.0, decayRate: 1.0);
        
        expect(
          () => need.satisfy(-10.0),
          throwsA(isA<AssertionError>()),
        );
      });
      
      test('handles zero satisfaction amount', () {
        final need = Need(type: 'hunger', value: 50.0, decayRate: 1.0);
        final originalValue = need.value;
        
        need.satisfy(0.0);
        
        expect(need.value, equals(originalValue));
      });
    });
    
    group('setValue', () {
      test('sets value to specified amount', () {
        final need = Need(type: 'hunger', value: 50.0, decayRate: 1.0);
        
        need.setValue(75.0);
        
        expect(need.value, equals(75.0));
      });
      
      test('throws assertion error for invalid value range', () {
        final need = Need(type: 'hunger', value: 50.0, decayRate: 1.0);
        
        expect(
          () => need.setValue(-10.0),
          throwsA(isA<AssertionError>()),
        );
        
        expect(
          () => need.setValue(150.0),
          throwsA(isA<AssertionError>()),
        );
      });
    });
    
    group('toString', () {
      test('provides readable string representation', () {
        final need = Need(type: 'hunger', value: 75.5, decayRate: 1.25);
        
        final result = need.toString();
        
        expect(result, contains('hunger'));
        expect(result, contains('75.5'));
        expect(result, contains('1.25'));
        expect(result, contains('critical: false'));
      });
      
      test('shows critical status correctly', () {
        final need = Need(type: 'hygiene', value: 15.0, decayRate: 2.0);
        
        final result = need.toString();
        
        expect(result, contains('critical: true'));
      });
    });
    
    group('equality', () {
      test('considers needs equal with same properties', () {
        final need1 = Need(type: 'hunger', value: 50.0, decayRate: 1.0);
        final need2 = Need(type: 'hunger', value: 50.0, decayRate: 1.0);
        
        expect(need1, equals(need2));
        expect(need1.hashCode, equals(need2.hashCode));
      });
      
      test('considers needs different with different properties', () {
        final need1 = Need(type: 'hunger', value: 50.0, decayRate: 1.0);
        final need2 = Need(type: 'hygiene', value: 50.0, decayRate: 1.0);
        final need3 = Need(type: 'hunger', value: 60.0, decayRate: 1.0);
        final need4 = Need(type: 'hunger', value: 50.0, decayRate: 2.0);
        
        expect(need1, isNot(equals(need2)));
        expect(need1, isNot(equals(need3)));
        expect(need1, isNot(equals(need4)));
      });
      
      test('handles identity equality', () {
        final need = Need(type: 'hunger', value: 50.0, decayRate: 1.0);
        
        expect(need, equals(need));
      });
    });
    
    group('constants', () {
      test('has correct constant values', () {
        expect(Need.criticalThreshold, equals(20.0));
        expect(Need.maxValue, equals(100.0));
        expect(Need.minValue, equals(0.0));
      });
    });
  });
}