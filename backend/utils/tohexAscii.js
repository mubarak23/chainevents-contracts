export function hexToAscii(hex) {
    hex = hex.startsWith('0x') ? hex.slice(2) : hex;

    let str = '';
    for (let i = 0; i < hex.length; i += 2) {
      const code = parseInt(hex.substr(i, 2), 16);
      if (code) str += String.fromCharCode(code);
    }
    return str;
}