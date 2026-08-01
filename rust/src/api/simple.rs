pub fn generate_signature(audio_bytes: Vec<u8>) -> Result<String, String> {
    use crate::fingerprinting::algorithm::SignatureGenerator;
    use crate::fingerprinting::communication::get_signature_json;
    
    // Generate the signature from raw bytes
    let decoded_sig = SignatureGenerator::make_signature_from_bytes(audio_bytes, Some(10))
        .map_err(|e| format!("Failed to generate signature: {}", e))?;
        
    // Format it into a communication struct and get the URI
    let comm_sig = get_signature_json(&decoded_sig)
        .map_err(|e| format!("Failed to generate JSON: {}", e))?;
        
    Ok(comm_sig.signature.uri)
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}
