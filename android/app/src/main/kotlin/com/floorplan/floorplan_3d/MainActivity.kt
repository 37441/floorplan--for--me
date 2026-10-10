package com.floorplan.floorplan_3d

import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.OutputStream

class MainActivity : FlutterActivity() {
    private var fName = "file"
    private var fMime = "application/octet-stream"
    private var fTotal = 0
    private var fReceived = 0
    private var fOut: OutputStream? = null
    private var fUri: Uri? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/save_file").setMethodCallHandler { call, result ->
            when (call.method) {
                // 分块保存：index=0 携带元信息并重建目标文件，末块返回最终路径
                "chunk" -> {
                    val index = call.argument<Int>("index") ?: 0
                    val data = Base64.decode(call.argument<String>("data") ?: "", Base64.DEFAULT)
                    if (index == 0) {
                        val meta = call.arguments as? Map<*, *>
                        fName = (meta?.get("name") as? String) ?: "file"
                        fMime = (meta?.get("mime") as? String) ?: "application/octet-stream"
                        fTotal = (meta?.get("total") as? Int) ?: 0
                        fReceived = 0
                        fUri = null
                        fOut?.close()
                        fOut = openOut(fName, fMime)
                    }
                    val out = fOut
                    if (out != null) {
                        out.write(data)
                        fReceived++
                        if (fTotal <= fReceived) {
                            out.flush()
                            out.close()
                            fOut = null
                            result.success(mapOf("path" to finalPath()))
                        } else {
                            result.success(null)
                        }
                    } else {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openOut(name: String, mime: String): OutputStream? {
        return if (Build.VERSION.SDK_INT >= 29) {
            val cv = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, mime)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            fUri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, cv)
            fUri?.let { contentResolver.openOutputStream(it) }
        } else {
            val dir = File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: filesDir, "downloads")
            dir.mkdirs()
            fUri = Uri.fromFile(File(dir, name))
            (fUri?.path?.let { File(it) })?.outputStream()
        }
    }

    private fun finalPath(): String {
        return if (Build.VERSION.SDK_INT >= 29) "下载/${fName}" else "${fUri?.path}"
    }
}