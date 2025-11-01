"""QR code generator adapter."""

import io
import qrcode
from ..interfaces import IQRGenerator


class QRCodeAdapter:
    """Adapter for QR code generation."""

    def generate(self, data: str) -> bytes:
        """Generate QR code PNG from text."""
        qr = qrcode.QRCode(
            version=1,
            box_size=10,
            border=5,
            error_correction=qrcode.constants.ERROR_CORRECT_L
        )
        qr.add_data(data)
        qr.make(fit=True)

        img = qr.make_image(fill_color="black", back_color="white")

        buf = io.BytesIO()
        img.save(buf, format='PNG')
        return buf.getvalue()
