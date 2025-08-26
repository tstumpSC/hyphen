import 'dart:js_interop';

@JS('createHyphenModule')
external JSPromise<JSObject> createHyphenModule();

@JS('globalThis')
external JSObject get globalThis;

@JS('injectDicFile')
external void injectDicFile(JSObject module, JSString filename, JSUint8Array data);
