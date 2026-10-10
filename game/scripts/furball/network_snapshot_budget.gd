class_name FurNetworkSnapshotBudget
extends RefCounted

# Shared transport limits match the full-capacity source validation budget.
const CHUNK_BYTES:=1000
const MAX_RAW_BYTES:=128*1024
const MAX_COMPRESSED_BYTES:=32*1024
const MAX_FRAGMENTS:=32
const MAX_ASSEMBLIES:=3

static func fits_encoded(raw_bytes:int,compressed_bytes:int)->bool:
	if raw_bytes<1 or raw_bytes>MAX_RAW_BYTES or compressed_bytes<1 or compressed_bytes>MAX_COMPRESSED_BYTES:return false
	return ceili(float(compressed_bytes)/CHUNK_BYTES)<=MAX_FRAGMENTS

static func accepts_fragment(sequence:int,last_sequence:int,index:int,count:int,raw_bytes:int,payload_bytes:int)->bool:
	return sequence>last_sequence and count>=1 and count<=MAX_FRAGMENTS and index>=0 and index<count and raw_bytes>=1 and raw_bytes<=MAX_RAW_BYTES and payload_bytes>=1 and payload_bytes<=CHUNK_BYTES
