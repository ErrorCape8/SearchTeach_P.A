package com.pa.searchteach.tutorias.service.colectivas;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class ValidadorArchivosChatTest {

	@Test
	void acceptsPcmWavAndRejectsInvalidAudioProperties() {
		assertTrue(ValidadorArchivosChat.archivoValidoAudioWav(wav(16)));
		assertFalse(ValidadorArchivosChat.archivoValidoAudioWav(wav(8)));

		byte[] invalidLength = wav(16);
		invalidLength[4] = 0;
		assertFalse(ValidadorArchivosChat.archivoValidoAudioWav(invalidLength));
	}

	private byte[] wav(int bitsPerSample) {
		byte[] bytes = new byte[48];
		writeText(bytes, 0, "RIFF");
		writeInt(bytes, 4, bytes.length - 8);
		writeText(bytes, 8, "WAVE");
		writeText(bytes, 12, "fmt ");
		writeInt(bytes, 16, 16);
		writeShort(bytes, 20, 1);
		writeShort(bytes, 22, 1);
		writeInt(bytes, 24, 16000);
		writeInt(bytes, 28, 32000);
		writeShort(bytes, 32, bitsPerSample / 8);
		writeShort(bytes, 34, bitsPerSample);
		writeText(bytes, 36, "data");
		writeInt(bytes, 40, bytes.length - 44);
		return bytes;
	}

	private void writeText(byte[] bytes, int offset, String value) {
		for (int index = 0; index < value.length(); index++) {
			bytes[offset + index] = (byte) value.charAt(index);
		}
	}

	private void writeShort(byte[] bytes, int offset, int value) {
		bytes[offset] = (byte) value;
		bytes[offset + 1] = (byte) (value >>> 8);
	}

	private void writeInt(byte[] bytes, int offset, int value) {
		bytes[offset] = (byte) value;
		bytes[offset + 1] = (byte) (value >>> 8);
		bytes[offset + 2] = (byte) (value >>> 16);
		bytes[offset + 3] = (byte) (value >>> 24);
	}
}
