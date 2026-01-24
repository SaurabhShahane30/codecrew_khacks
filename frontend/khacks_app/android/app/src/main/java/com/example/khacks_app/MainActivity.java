package com.example.khacks_app;



import android.app.AlarmManager;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.provider.Settings;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {

    private static final String CHANNEL = "exact_alarm_permission";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHANNEL
        ).setMethodCallHandler(
                (call, result) -> {
                    if (call.method.equals("requestExactAlarm")) {
                        requestExactAlarmPermission();
                        result.success(true);
                    } else {
                        result.notImplemented();
                    }
                }
        );
    }

    private void requestExactAlarmPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            AlarmManager alarmManager =
                    (AlarmManager) getSystemService(Context.ALARM_SERVICE);

            if (!alarmManager.canScheduleExactAlarms()) {
                Intent intent =
                        new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM);
                startActivity(intent);
            }
        }
    }
}
