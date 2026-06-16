// Minimal local typing for qrcode-generator (ships no bundled types). We only use
// the data-URL path: qrcode(0,'M').addData(url).make() then createDataURL().
declare module 'qrcode-generator' {
  interface QRCode {
    addData(data: string): void
    make(): void
    createDataURL(cellSize?: number, margin?: number): string
  }
  const qrcode: (typeNumber: number, errorCorrectionLevel: 'L' | 'M' | 'Q' | 'H') => QRCode
  export default qrcode
}
