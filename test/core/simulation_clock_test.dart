import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sims_like_game/core/simulation_clock.dart';
import 'package:sims_like_game/core/deterministic_simulation_clock.dart';
import 'package:sims_like_game/core/debug_clock_controller.dart';

void main() {
  group('SimulationClock', () {
    late DeterministicSimulationClock clock;
    
    setUp(() {
      clock = DeterministicSimulationClock();
    });
    
    tearDown(() {
      clock.dispose();
    });
    
    test('should have correct constants', () {
      expect(SimulationClock.TICKS_PER_SECOND, equals(15));
      expect(SimulationClock.TICK_DURATION, equals(const Duration(milliseconds: 67)));
    });
    
    test('should start in stopped state', () {
      expect(clock.currentTick, equals(0));
      expect(clock.isRunning, isFalse);
      expect(clock.isPaused, isFalse);
      expect(clock.speedMultiplier, equals(1.0));
    });
    
    test('should start and emit tick events', () async {
      final tickEvents = <TickEvent>[];
      final subscription = clock.tickStream.listen(tickEvents.add);
      
      clock.start();
      expect(clock.isRunning, isTrue);
      expect(clock.isPaused, isFalse);
      
      // Wait for a few ticks
      await Future.delayed(const Duration(milliseconds: 200));
      
      expect(tickEvents.length, greaterThan(0));
      expect(clock.currentTick, greaterThan(0));
      
      // Verify tick event structure
      final firstTick = tickEvents.first;
      expect(firstTick.tick, equals(1));
      expect(firstTick.simulationTime, closeTo(1.0 / 15.0, 0.01));
      expect(firstTick.deltaTime, equals(SimulationClock.TICK_DURATION));
      
      subscription.cancel();
    });
    
    test('should pause and resume correctly', () async {
      final tickEvents = <TickEvent>[];
      final subscription = clock.tickStream.listen(tickEvents.add);
      
      clock.start();
      await Future.delayed(const Duration(milliseconds: 100));
      
      final ticksBeforePause = clock.currentTick;
      clock.pause();
      
      expect(clock.isRunning, isTrue);
      expect(clock.isPaused, isTrue);
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Should not advance while paused
      expect(clock.currentTick, equals(ticksBeforePause));
      
      clock.resume();
      expect(clock.isPaused, isFalse);
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Should advance after resume
      expect(clock.currentTick, greaterThan(ticksBeforePause));
      
      subscription.cancel();
    });
    
    test('should execute single step when paused', () {
      final tickEvents = <TickEvent>[];
      final subscription = clock.tickStream.listen(tickEvents.add);
      
      clock.start();
      clock.pause();
      
      final ticksBefore = clock.currentTick;
      clock.step();
      
      expect(clock.currentTick, equals(ticksBefore + 1));
      expect(tickEvents.length, equals(ticksBefore + 1));
      
      subscription.cancel();
    });
    
    test('should not allow step while running', () {
      clock.start();
      
      expect(() => clock.step(), throwsStateError);
    });
    
    test('should change speed multiplier', () async {
      clock.setSpeedMultiplier(2.0);
      expect(clock.speedMultiplier, equals(2.0));
      
      clock.setSpeedMultiplier(0.5);
      expect(clock.speedMultiplier, equals(0.5));
      
      // Should clamp to valid values
      clock.setSpeedMultiplier(1.7);
      expect(clock.speedMultiplier, equals(2.0)); // Closest valid value
    });
    
    test('should reset to initial state', () async {
      clock.start();
      await Future.delayed(const Duration(milliseconds: 100));
      
      expect(clock.currentTick, greaterThan(0));
      
      clock.reset();
      
      expect(clock.currentTick, equals(0));
      expect(clock.isRunning, isFalse);
      expect(clock.isPaused, isFalse);
      expect(clock.speedMultiplier, equals(1.0));
    });
    
    test('should calculate simulation time correctly', () {
      clock.start();
      clock.pause();
      
      // Execute 15 ticks (1 second of simulation time)
      for (int i = 0; i < 15; i++) {
        clock.step();
      }
      
      expect(clock.simulationTime.inSeconds, equals(1));
    });
  });
  
  group('DebugClockController', () {
    late DeterministicSimulationClock clock;
    late DebugClockController debugController;
    
    setUp(() {
      clock = DeterministicSimulationClock();
      debugController = DebugClockController(clock);
    });
    
    tearDown(() {
      clock.dispose();
    });
    
    test('should track tick history', () async {
      clock.start();
      await Future.delayed(const Duration(milliseconds: 150));
      
      final history = debugController.tickHistory;
      expect(history.length, greaterThan(0));
      expect(history.first.tick, equals(1));
    });
    
    test('should toggle pause/resume', () {
      clock.start();
      expect(clock.isPaused, isFalse);
      
      debugController.togglePause();
      expect(clock.isPaused, isTrue);
      
      debugController.togglePause();
      expect(clock.isPaused, isFalse);
    });
    
    test('should cycle through speed multipliers', () {
      expect(clock.speedMultiplier, equals(1.0));
      
      debugController.cycleSpeed();
      expect(clock.speedMultiplier, equals(2.0));
      
      debugController.cycleSpeed();
      expect(clock.speedMultiplier, equals(3.0));
      
      debugController.cycleSpeed();
      expect(clock.speedMultiplier, equals(0.5));
      
      debugController.cycleSpeed();
      expect(clock.speedMultiplier, equals(1.0));
    });
    
    test('should execute single and multiple steps', () {
      clock.start();
      clock.pause();
      
      final ticksBefore = clock.currentTick;
      
      debugController.stepOnce();
      expect(clock.currentTick, equals(ticksBefore + 1));
      
      debugController.stepMultiple(3);
      expect(clock.currentTick, equals(ticksBefore + 4));
    });
    
    test('should not allow stepping while running', () {
      clock.start();
      
      expect(() => debugController.stepOnce(), throwsStateError);
      expect(() => debugController.stepMultiple(3), throwsStateError);
    });
    
    test('should provide performance metrics', () async {
      clock.start();
      await Future.delayed(const Duration(milliseconds: 100));
      
      final metrics = debugController.performanceMetrics;
      expect(metrics.currentTick, greaterThan(0));
      expect(metrics.isRunning, isTrue);
      expect(metrics.isPaused, isFalse);
      expect(metrics.speedMultiplier, equals(1.0));
    });
    
    test('should generate debug info string', () async {
      clock.start();
      await Future.delayed(const Duration(milliseconds: 50));
      
      final debugInfo = debugController.getDebugInfo();
      expect(debugInfo, contains('Tick:'));
      expect(debugInfo, contains('Status:'));
      expect(debugInfo, contains('Speed:'));
    });
  });
}