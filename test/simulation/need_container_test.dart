import 'package:flutter_test/flutter_test.dart';
import 'package:sims_like_game/simulation/need.dart';
import 'package:sims_like_game/simulation/need_container.dart';

void main() {
  group('NeedContainer', () {
    group('constructor', () {
      test('creates empty container', () {
        final container = NeedContainer();
        
        expect(container.isEmpty, isTrue);
        expect(container.length, equals(0));
      });
      
      test('creates container with initial needs', () {
        final needs = [
          Need(type: 'hunger', value: 80.0, decayRate: 1.0),
          Need(type: 'hygiene', value: 60.0, decayRate: 1.5),
        ];
        
        final container = NeedContainer.withNeeds(needs);
        
        expect(container.isEmpty, isFalse);
        expect(container.length, equals(2));
        expect(container.getNeed('hunger'), isNotNull);
        expect(container.getNeed('hygiene'), isNotNull);
      });
    });
    
    group('addNeed', () {
      test('adds need successfully', () {
        final container = NeedContainer();
        final need = Need(type: 'hunger', value: 50.0, decayRate: 1.0);
        
        container.addNeed(need);
        
        expect(container.length, equals(1));
        expect(container.getNeed('hunger'), equals(need));
      });
      
      test('throws error when adding duplicate need type', () {
        final container = NeedContainer();
        final need1 = Need(type: 'hunger', value: 50.0, decayRate: 1.0);
        final need2 = Need(type: 'hunger', value: 70.0, decayRate: 2.0);
        
        container.addNeed(need1);
        
        expect(
          () => container.addNeed(need2),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
    
    group('removeNeed', () {
      test('removes existing need successfully', () {
        final container = NeedContainer();
        final need = Need(type: 'hunger', value: 50.0, decayRate: 1.0);
        
        container.addNeed(need);
        final result = container.removeNeed('hunger');
        
        expect(result, isTrue);
        expect(container.length, equals(0));
        expect(container.getNeed('hunger'), isNull);
      });
      
      test('returns false when removing non-existent need', () {
        final container = NeedContainer();
        
        final result = container.removeNeed('nonexistent');
        
        expect(result, isFalse);
      });
    });
    
    group('getNeed', () {
      test('returns existing need', () {
        final container = NeedContainer();
        final need = Need(type: 'hunger', value: 50.0, decayRate: 1.0);
        
        container.addNeed(need);
        
        expect(container.getNeed('hunger'), equals(need));
      });
      
      test('returns null for non-existent need', () {
        final container = NeedContainer();
        
        expect(container.getNeed('nonexistent'), isNull);
      });
    });
    
    group('allNeeds and needTypes', () {
      test('returns all needs and types correctly', () {
        final container = NeedContainer();
        final hunger = Need(type: 'hunger', value: 80.0, decayRate: 1.0);
        final hygiene = Need(type: 'hygiene', value: 60.0, decayRate: 1.5);
        
        container.addNeed(hunger);
        container.addNeed(hygiene);
        
        final allNeeds = container.allNeeds.toList();
        final needTypes = container.needTypes.toList();
        
        expect(allNeeds, hasLength(2));
        expect(allNeeds, contains(hunger));
        expect(allNeeds, contains(hygiene));
        
        expect(needTypes, hasLength(2));
        expect(needTypes, contains('hunger'));
        expect(needTypes, contains('hygiene'));
      });
      
      test('returns empty collections for empty container', () {
        final container = NeedContainer();
        
        expect(container.allNeeds, isEmpty);
        expect(container.needTypes, isEmpty);
      });
    });
    
    group('tick', () {
      test('processes decay for all needs', () {
        final container = NeedContainer();
        final hunger = Need(type: 'hunger', value: 100.0, decayRate: 2.0);
        final hygiene = Need(type: 'hygiene', value: 80.0, decayRate: 1.0);
        
        container.addNeed(hunger);
        container.addNeed(hygiene);
        
        container.tick(5.0); // 5 seconds
        
        expect(hunger.value, equals(90.0)); // 100 - (2.0 * 5.0)
        expect(hygiene.value, equals(75.0)); // 80 - (1.0 * 5.0)
      });
      
      test('handles empty container', () {
        final container = NeedContainer();
        
        // Should not throw
        container.tick(5.0);
      });
      
      test('throws assertion error for negative delta time', () {
        final container = NeedContainer();
        
        expect(
          () => container.tick(-1.0),
          throwsA(isA<AssertionError>()),
        );
      });
    });
    
    group('getMostUrgent', () {
      test('returns need with highest deficit', () {
        final container = NeedContainer();
        final hunger = Need(type: 'hunger', value: 30.0, decayRate: 1.0); // deficit: 70
        final hygiene = Need(type: 'hygiene', value: 10.0, decayRate: 1.0); // deficit: 90
        final social = Need(type: 'social', value: 60.0, decayRate: 1.0); // deficit: 40
        
        container.addNeed(hunger);
        container.addNeed(hygiene);
        container.addNeed(social);
        
        final mostUrgent = container.getMostUrgent();
        
        expect(mostUrgent, equals(hygiene));
      });
      
      test('returns null for empty container', () {
        final container = NeedContainer();
        
        expect(container.getMostUrgent(), isNull);
      });
      
      test('handles ties by returning one of the tied needs', () {
        final container = NeedContainer();
        final hunger = Need(type: 'hunger', value: 50.0, decayRate: 1.0);
        final hygiene = Need(type: 'hygiene', value: 50.0, decayRate: 1.0);
        
        container.addNeed(hunger);
        container.addNeed(hygiene);
        
        final mostUrgent = container.getMostUrgent();
        
        expect(mostUrgent, isIn([hunger, hygiene]));
      });
    });
    
    group('getDeficit', () {
      test('returns correct deficit for existing need', () {
        final container = NeedContainer();
        final need = Need(type: 'hunger', value: 25.0, decayRate: 1.0);
        
        container.addNeed(need);
        
        expect(container.getDeficit('hunger'), equals(75.0));
      });
      
      test('returns 0 for non-existent need', () {
        final container = NeedContainer();
        
        expect(container.getDeficit('nonexistent'), equals(0.0));
      });
    });
    
    group('getCriticalNeeds', () {
      test('returns only critical needs', () {
        final container = NeedContainer();
        final hunger = Need(type: 'hunger', value: 15.0, decayRate: 1.0); // critical
        final hygiene = Need(type: 'hygiene', value: 50.0, decayRate: 1.0); // not critical
        final social = Need(type: 'social', value: 10.0, decayRate: 1.0); // critical
        
        container.addNeed(hunger);
        container.addNeed(hygiene);
        container.addNeed(social);
        
        final criticalNeeds = container.getCriticalNeeds();
        
        expect(criticalNeeds, hasLength(2));
        expect(criticalNeeds, contains(hunger));
        expect(criticalNeeds, contains(social));
        expect(criticalNeeds, isNot(contains(hygiene)));
      });
      
      test('returns empty list when no needs are critical', () {
        final container = NeedContainer();
        final need = Need(type: 'hunger', value: 50.0, decayRate: 1.0);
        
        container.addNeed(need);
        
        expect(container.getCriticalNeeds(), isEmpty);
      });
    });
    
    group('hasCriticalNeeds', () {
      test('returns true when critical needs exist', () {
        final container = NeedContainer();
        final need = Need(type: 'hunger', value: 15.0, decayRate: 1.0);
        
        container.addNeed(need);
        
        expect(container.hasCriticalNeeds, isTrue);
      });
      
      test('returns false when no critical needs exist', () {
        final container = NeedContainer();
        final need = Need(type: 'hunger', value: 50.0, decayRate: 1.0);
        
        container.addNeed(need);
        
        expect(container.hasCriticalNeeds, isFalse);
      });
      
      test('returns false for empty container', () {
        final container = NeedContainer();
        
        expect(container.hasCriticalNeeds, isFalse);
      });
    });
    
    group('averageSatisfaction', () {
      test('calculates correct average for multiple needs', () {
        final container = NeedContainer();
        final hunger = Need(type: 'hunger', value: 60.0, decayRate: 1.0); // 0.6
        final hygiene = Need(type: 'hygiene', value: 80.0, decayRate: 1.0); // 0.8
        
        container.addNeed(hunger);
        container.addNeed(hygiene);
        
        expect(container.averageSatisfaction, equals(0.7)); // (0.6 + 0.8) / 2
      });
      
      test('returns 1.0 for empty container', () {
        final container = NeedContainer();
        
        expect(container.averageSatisfaction, equals(1.0));
      });
    });
    
    group('lowestSatisfaction', () {
      test('returns lowest satisfaction among needs', () {
        final container = NeedContainer();
        final hunger = Need(type: 'hunger', value: 30.0, decayRate: 1.0); // 0.3
        final hygiene = Need(type: 'hygiene', value: 70.0, decayRate: 1.0); // 0.7
        
        container.addNeed(hunger);
        container.addNeed(hygiene);
        
        expect(container.lowestSatisfaction, equals(0.3));
      });
      
      test('returns 1.0 for empty container', () {
        final container = NeedContainer();
        
        expect(container.lowestSatisfaction, equals(1.0));
      });
    });
    
    group('satisfyNeed', () {
      test('satisfies existing need successfully', () {
        final container = NeedContainer();
        final need = Need(type: 'hunger', value: 30.0, decayRate: 1.0);
        
        container.addNeed(need);
        final result = container.satisfyNeed('hunger', 20.0);
        
        expect(result, isTrue);
        expect(need.value, equals(50.0));
      });
      
      test('returns false for non-existent need', () {
        final container = NeedContainer();
        
        final result = container.satisfyNeed('nonexistent', 20.0);
        
        expect(result, isFalse);
      });
    });
    
    group('setNeedValue', () {
      test('sets existing need value successfully', () {
        final container = NeedContainer();
        final need = Need(type: 'hunger', value: 30.0, decayRate: 1.0);
        
        container.addNeed(need);
        final result = container.setNeedValue('hunger', 75.0);
        
        expect(result, isTrue);
        expect(need.value, equals(75.0));
      });
      
      test('returns false for non-existent need', () {
        final container = NeedContainer();
        
        final result = container.setNeedValue('nonexistent', 75.0);
        
        expect(result, isFalse);
      });
    });
    
    group('toString', () {
      test('provides readable string for container with needs', () {
        final container = NeedContainer();
        final hunger = Need(type: 'hunger', value: 75.5, decayRate: 1.0);
        final hygiene = Need(type: 'hygiene', value: 60.0, decayRate: 1.5);
        
        container.addNeed(hunger);
        container.addNeed(hygiene);
        
        final result = container.toString();
        
        expect(result, contains('NeedContainer'));
        expect(result, contains('hunger: 75.5'));
        expect(result, contains('hygiene: 60.0'));
      });
      
      test('shows empty container correctly', () {
        final container = NeedContainer();
        
        final result = container.toString();
        
        expect(result, equals('NeedContainer(empty)'));
      });
    });
    
    group('integration scenarios', () {
      test('simulates realistic need decay over time', () {
        final container = NeedContainer();
        final hunger = Need(type: 'hunger', value: 100.0, decayRate: 1.0);
        final hygiene = Need(type: 'hygiene', value: 100.0, decayRate: 0.5);
        final social = Need(type: 'social', value: 100.0, decayRate: 0.2);
        
        container.addNeed(hunger);
        container.addNeed(hygiene);
        container.addNeed(social);
        
        // Simulate 1 hour (3600 seconds) of game time
        container.tick(3600.0);
        
        expect(hunger.value, equals(0.0)); // Fully depleted
        expect(hygiene.value, equals(0.0)); // Fully depleted  
        expect(social.value, equals(0.0)); // 100 - (0.2 * 3600) = 100 - 720 = -620, clamped to 0
        
        expect(container.getMostUrgent()?.type, equals('hunger')); // Both hunger and hygiene at 0, but hunger added first
        expect(container.hasCriticalNeeds, isTrue);
        expect(container.getCriticalNeeds(), hasLength(3));
      });
      
      test('handles need satisfaction and re-decay', () {
        final container = NeedContainer();
        final hunger = Need(type: 'hunger', value: 10.0, decayRate: 2.0);
        
        container.addNeed(hunger);
        
        expect(hunger.isCritical, isTrue);
        
        // Satisfy the need
        container.satisfyNeed('hunger', 80.0);
        expect(hunger.value, equals(90.0));
        expect(hunger.isCritical, isFalse);
        
        // Let it decay again
        container.tick(40.0); // 40 seconds
        expect(hunger.value, equals(10.0)); // 90 - (2.0 * 40)
        expect(hunger.isCritical, isTrue);
      });
    });
  });
}