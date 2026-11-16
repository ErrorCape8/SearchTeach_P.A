package com.pa.searchteach.tutorias.service.colectivas;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.util.zip.ZipInputStream;

/** Valida el contenido real de los adjuntos permitidos en el chat. */
final class ValidadorArchivosChat {

	private ValidadorArchivosChat() {}

	static boolean archivoValido(String extension, byte[] bytes) {
		if ("pdf".equals(extension)) {
			return bytes.length >= 5 && bytes[0] == '%' && bytes[1] == 'P'
					&& bytes[2] == 'D' && bytes[3] == 'F' && bytes[4] == '-';
		}

		if (!"docx".equals(extension) || bytes.length < 4 || bytes[0] != 'P' || bytes[1] != 'K') return false;
		boolean document = false;
		boolean contentTypes = false;
		boolean macroProject = false;
		long uncompressedBytes = 0;
		try (ZipInputStream zip = new ZipInputStream(new ByteArrayInputStream(bytes))) {
			java.util.zip.ZipEntry entry;
			byte[] buffer = new byte[4096];
			while ((entry = zip.getNextEntry()) != null) {
				if ("word/document.xml".equals(entry.getName())) document = true;
				if ("[Content_Types].xml".equals(entry.getName())) contentTypes = true;
				if ("word/vbaProject.bin".equalsIgnoreCase(entry.getName())) macroProject = true;
				int read;
				while ((read = zip.read(buffer)) != -1) {
					uncompressedBytes += read;
					if (uncompressedBytes > 24L * 1024 * 1024) return false;
				}
			}
		} catch (IOException error) {
			return false;
		}
		return document && contentTypes && !macroProject;
	}

	static boolean archivoValidoAudioWebm(byte[] bytes) {
		return bytes.length >= 4
				&& (bytes[0] & 0xFF) == 0x1A
				&& (bytes[1] & 0xFF) == 0x45
				&& (bytes[2] & 0xFF) == 0xDF
				&& (bytes[3] & 0xFF) == 0xA3;
	}

	static boolean archivoValidoAudioWav(byte[] bytes) {
		if (bytes.length < 44
				|| !coincide(bytes, 0, "RIFF")
				|| !coincide(bytes, 8, "WAVE")
				|| !coincide(bytes, 12, "fmt ")
				|| !coincide(bytes, 36, "data")) {
			return false;
		}
		int channels = unsignedShort(bytes, 22);
		int bitsPerSample = unsignedShort(bytes, 34);
		long dataLength = unsignedInt(bytes, 40);
		int blockAlign = unsignedShort(bytes, 32);
		return unsignedInt(bytes, 4) == bytes.length - 8L
				&& unsignedInt(bytes, 16) == 16
				&& unsignedShort(bytes, 20) == 1
				&& channels > 0
				&& unsignedInt(bytes, 24) > 0
				&& bitsPerSample == 16
				&& blockAlign == channels * (bitsPerSample / 8)
				&& dataLength > 0
				&& dataLength == bytes.length - 44L
				&& dataLength % blockAlign == 0;
	}

	private static boolean coincide(byte[] bytes, int offset, String value) {
		for (int index = 0; index < value.length(); index++) {
			if (bytes[offset + index] != value.charAt(index)) return false;
		}
		return true;
	}

	private static int unsignedShort(byte[] bytes, int offset) {
		return (bytes[offset] & 0xFF) | ((bytes[offset + 1] & 0xFF) << 8);
	}

	private static long unsignedInt(byte[] bytes, int offset) {
		return Integer.toUnsignedLong((bytes[offset] & 0xFF)
				| ((bytes[offset + 1] & 0xFF) << 8)
				| ((bytes[offset + 2] & 0xFF) << 16)
				| ((bytes[offset + 3] & 0xFF) << 24));
	}
}
