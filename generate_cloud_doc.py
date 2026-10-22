# -*- coding: utf-8 -*-
"""
Script tạo tài liệu Word hoàn chỉnh:
BÁO CÁO PHÂN TÍCH HỆ THỐNG VÀ LẬP PHƯƠNG ÁN CHUYỂN ĐỔI, TÍCH HỢP ĐIỆN TOÁN ĐÁM MÂY (CLOUD)
DỰA TRÊN ỨNG DỤNG BÀI THỰC HÀNH 1 - QUẢN LÝ TÀI LIỆU HỌC TẬP (CashewDoc)
Tên tệp xuất: phan_tich_va_lap_phuong_an.docx
"""

import os
import sys

if sys.platform.startswith('win'):
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

import matplotlib.pyplot as plt
import matplotlib.patches as patches
import docx
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

WORKSPACE_DIR = r"d:\Nam4\Mobile\TH1"
IMG_DIR = os.path.join(WORKSPACE_DIR, "assets", "diagrams")
os.makedirs(IMG_DIR, exist_ok=True)
DOCX_OUT = os.path.join(WORKSPACE_DIR, "phan_tich_va_lap_phuong_an.docx")

# ==============================================================================
# PHẦN 1: TẠO CÁC SƠ ĐỒ ĐỒ HỌA CHUYÊN NGHIỆP (300 DPI)
# ==============================================================================

def generate_traditional_vs_cloud_arch_diagram():
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(13.5, 7.2), dpi=300)
    fig.patch.set_facecolor('#F8FAFC')

    # BÊN TRÁI: KIẾN TRÚC HIỆN TẠI CỦA BÀI THỰC HÀNH (LOCAL / CLIENT-CENTRIC CASHEWDOC)
    ax1.set_xlim(0, 100)
    ax1.set_ylim(0, 100)
    ax1.axis('off')
    ax1.set_facecolor('#F8FAFC')
    ax1.text(50, 96, "MÔ HÌNH HIỆN TẠI (BÀI THỰC HÀNH 1 - LOCAL CASHEWDOC)", ha='center', fontsize=10.5, fontweight='bold', color='#991B1B')
    ax1.text(50, 92, "(Cục bộ trên thiết bị di động / SQLite FFI / Local Storage)", ha='center', fontsize=8.5, color='#7F1D1D', style='italic')

    # Frontend
    b_fe1 = patches.FancyBboxPatch((10, 72), 80, 16, boxstyle="round,pad=0.8,rounding_size=2",
                                  facecolor="#DBEAFE", edgecolor="#1D4ED8", linewidth=1.8)
    ax1.add_patch(b_fe1)
    ax1.text(50, 83, "FRONTEND: FLUTTER MOBILE APP", ha='center', va='center', fontsize=10, fontweight='bold', color="#1E3A8A")
    ax1.text(50, 77.5, "HomeScreen, DetailScreen, DocumentCard, FilePicker", ha='center', va='center', fontsize=8.5, color="#2563EB")
    ax1.text(50, 74, "DocumentController (ChangeNotifier + Reactive Streams)", ha='center', va='center', fontsize=7.5, color="#1D4ED8")

    # Service Logic
    b_be1 = patches.FancyBboxPatch((10, 46), 80, 18, boxstyle="round,pad=0.8,rounding_size=2",
                                  facecolor="#FEF3C7", edgecolor="#D97706", linewidth=2)
    ax1.add_patch(b_be1)
    ax1.text(50, 58, "APPLICATION LOGIC (SERVICE LAYER)", ha='center', va='center', fontsize=10, fontweight='bold', color="#92400E")
    ax1.text(50, 52.5, "DocumentService, SubjectService, SearchService", ha='center', va='center', fontsize=8.5, color="#B45309")
    ax1.text(50, 48.5, "Validation, UUID v4 (UuidHelper), Soft-Delete State Machine", ha='center', va='center', fontsize=7.5, color="#78350F")

    # Database & Storage
    b_db1 = patches.FancyBboxPatch((10, 20), 38, 18, boxstyle="round,pad=0.8,rounding_size=2",
                                  facecolor="#E0E7FF", edgecolor="#4338CA", linewidth=1.8)
    ax1.add_patch(b_db1)
    ax1.text(29, 31, "CSDL SQLITE CỤC BỘ", ha='center', va='center', fontsize=9, fontweight='bold', color="#3730A3")
    ax1.text(29, 25, "AppDatabase (sqflite)\nBảng: documents, subjects,\nattachments, delete_logs", ha='center', va='center', fontsize=7.5, color="#4338CA")

    b_st1 = patches.FancyBboxPatch((52, 20), 38, 18, boxstyle="round,pad=0.8,rounding_size=2",
                                  facecolor="#FEE2E2", edgecolor="#DC2626", linewidth=1.8)
    ax1.add_patch(b_st1)
    ax1.text(71, 31, "BỘ NHỚ MÁY (LOCAL)", ha='center', va='center', fontsize=9, fontweight='bold', color="#991B1B")
    ax1.text(71, 25, "Android Internal App Sandbox\nLưu tệp .pdf, .docx, .pptx\n(Đầy bộ nhớ / Dễ mất khi gỡ app)", ha='center', va='center', fontsize=7.5, color="#7F1D1D")

    # Risk box
    b_risk = patches.FancyBboxPatch((10, 3), 80, 13, boxstyle="round,pad=0.5,rounding_size=1",
                                   facecolor="#FEF2F2", edgecolor="#F87171", linewidth=1.2, linestyle='--')
    ax1.add_patch(b_risk)
    ax1.text(50, 11, "HẠN CHẾ CỐ HỮU HIỆN TẠI:", ha='center', fontsize=8, fontweight='bold', color="#991B1B")
    ax1.text(50, 6.5, "• Dữ liệu cô lập trên 1 máy • Mất máy là mất toàn bộ tài liệu\n• Không đồng bộ sang Laptop • Không chia sẻ được cho bạn bè", 
             ha='center', fontsize=7.5, color="#7F1D1D")

    arrow_p = dict(arrowstyle="<|-|>", color="#D97706", lw=2, mutation_scale=12)
    ax1.annotate('', xy=(50, 64), xytext=(50, 72), arrowprops=arrow_p)
    ax1.annotate('', xy=(29, 38), xytext=(35, 46), arrowprops=dict(arrowstyle="<|-|>", color="#4338CA", lw=1.8, mutation_scale=10))
    ax1.annotate('', xy=(71, 38), xytext=(65, 46), arrowprops=dict(arrowstyle="<|-|>", color="#DC2626", lw=1.8, mutation_scale=10))

    # BÊN PHẢI: KIẾN TRÚC TÍCH HỢP CLOUD (MODERN CLOUD DMS CHO CASHEWDOC)
    ax2.set_xlim(0, 100)
    ax2.set_ylim(0, 100)
    ax2.axis('off')
    ax2.set_facecolor('#F8FAFC')
    ax2.text(50, 96, "MÔ HÌNH SAU TÍCH HỢP CLOUD (CLOUD-ENHANCED CASHEWDOC)", ha='center', fontsize=10.5, fontweight='bold', color='#15803D')
    ax2.text(50, 92, "(Bảo tồn Offline-First + Lưu trữ S3 Vô hạn + Đồng bộ Đám mây)", ha='center', fontsize=8.5, color='#166534', style='italic')

    # Frontend
    b_fe2 = patches.FancyBboxPatch((10, 72), 80, 16, boxstyle="round,pad=0.8,rounding_size=2",
                                  facecolor="#DBEAFE", edgecolor="#1D4ED8", linewidth=1.8)
    ax2.add_patch(b_fe2)
    ax2.text(50, 83, "CLIENT (Flutter Mobile App + Web Portal)", ha='center', va='center', fontsize=10, fontweight='bold', color="#1E3A8A")
    ax2.text(50, 77.5, "Offline Cache (SQLite) + CloudSyncService", ha='center', va='center', fontsize=8.5, color="#2563EB")
    ax2.text(50, 74, "Direct Upload tệp lên Amazon S3 qua Pre-signed URL", ha='center', va='center', fontsize=7.5, color="#1D4ED8")

    # Cloud Backend
    b_be2 = patches.FancyBboxPatch((10, 46), 38, 18, boxstyle="round,pad=0.8,rounding_size=2",
                                  facecolor="#DCFCE7", edgecolor="#16A34A", linewidth=1.8)
    ax2.add_patch(b_be2)
    ax2.text(29, 58, "CLOUD BACKEND API", ha='center', va='center', fontsize=9.5, fontweight='bold', color="#166534")
    ax2.text(29, 52, "AWS ECS Fargate / Lambda\n(Sync Engine, Pre-signed URL,\nXác thực JWT, Audit Trail)", ha='center', va='center', fontsize=7.5, color="#15803D")

    # Cloud Storage S3
    b_s3 = patches.FancyBboxPatch((52, 46), 38, 18, boxstyle="round,pad=0.8,rounding_size=2",
                                 facecolor="#FEF3C7", edgecolor="#D97706", linewidth=2)
    ax2.add_patch(b_s3)
    ax2.text(71, 58, "OBJECT STORAGE (S3)", ha='center', va='center', fontsize=9.5, fontweight='bold', color="#92400E")
    ax2.text(71, 52, "Amazon S3 Bucket (Private)\n(Lưu tệp .pdf, .docx - Vô hạn,\nMã hóa AES-256, S3 Lifecycle)", ha='center', va='center', fontsize=7.5, color="#B45309")

    # Database Cloud
    b_db2 = patches.FancyBboxPatch((10, 20), 38, 18, boxstyle="round,pad=0.8,rounding_size=2",
                                  facecolor="#E0E7FF", edgecolor="#4338CA", linewidth=1.8)
    ax2.add_patch(b_db2)
    ax2.text(29, 31, "CLOUD DB (AMAZON RDS)", ha='center', va='center', fontsize=9, fontweight='bold', color="#3730A3")
    ax2.text(29, 25, "PostgreSQL Cloud Database\n(Đồng bộ đa thiết bị theo UUID\nvà delete_logs của Cashew)", ha='center', va='center', fontsize=7.5, color="#4338CA")

    # CDN CloudFront
    b_cdn = patches.FancyBboxPatch((52, 20), 38, 18, boxstyle="round,pad=0.8,rounding_size=2",
                                  facecolor="#F3E8FF", edgecolor="#7E22CE", linewidth=1.8)
    ax2.add_patch(b_cdn)
    ax2.text(71, 31, "EDGE CDN (CLOUDFRONT)", ha='center', va='center', fontsize=9, fontweight='bold', color="#6B21A8")
    ax2.text(71, 25, "Mạng phân phối tệp toàn cầu\n(Cache bài giảng, độ trễ <50ms,\nSigned URLs có thời hạn)", ha='center', va='center', fontsize=7.5, color="#7E22CE")

    # Benefits box
    b_ben = patches.FancyBboxPatch((10, 3), 80, 13, boxstyle="round,pad=0.5,rounding_size=1",
                                  facecolor="#F0FDF4", edgecolor="#4ADE80", linewidth=1.2)
    ax2.add_patch(b_ben)
    ax2.text(50, 11, "ƯU THẾ VƯỢT TRỘI SAU CHUYỂN ĐỔI:", ha='center', fontsize=8, fontweight='bold', color="#166534")
    ax2.text(50, 6.5, "• Độ bền 99.999999999% • Đồng bộ đa thiết bị tức thì\n• Giải phóng 100% dung lượng máy • Chia sẻ link tài liệu an toàn", 
             ha='center', fontsize=7.5, color="#15803D")

    # Arrows for Cloud
    ax2.annotate('', xy=(29, 64), xytext=(29, 72), arrowprops=dict(arrowstyle="-|>", color="#16A34A", lw=2, mutation_scale=12))
    ax2.text(20, 68, "1. Xin Pre-signed URL", fontsize=7, color="#166534")

    ax2.annotate('', xy=(71, 64), xytext=(71, 72), arrowprops=dict(arrowstyle="-|>", color="#D97706", lw=2.5, mutation_scale=14))
    ax2.text(72, 68, "2. Direct Upload (S3)", fontsize=7, color="#D97706", fontweight='bold')

    ax2.annotate('', xy=(29, 38), xytext=(29, 46), arrowprops=dict(arrowstyle="<|-|>", color="#4338CA", lw=1.8, mutation_scale=10))
    ax2.annotate('', xy=(71, 38), xytext=(71, 46), arrowprops=dict(arrowstyle="<|-|>", color="#7E22CE", lw=1.8, mutation_scale=10))

    img_path = os.path.join(IMG_DIR, "traditional_vs_cloud_arch.png")
    plt.tight_layout()
    plt.savefig(img_path, dpi=300, bbox_inches='tight', facecolor=fig.get_facecolor())
    plt.close()
    return img_path

def generate_cloud_data_flow_diagram():
    fig, ax = plt.subplots(figsize=(11.5, 6.8), dpi=300)
    ax.set_xlim(0, 100)
    ax.set_ylim(0, 100)
    ax.axis('off')
    fig.patch.set_facecolor('#FFFFFF')
    ax.set_facecolor('#FFFFFF')

    ax.text(50, 96, "LUỒNG DỮ LIỆU TẢI LÊN & TRUY XUẤT TÀI LIỆU TRÊN NỀN TẢNG CLOUD (PRE-SIGNED URL)",
            ha='center', fontsize=11, fontweight='bold', color='#1E3A8A')
    ax.text(50, 92, "Áp dụng cho ứng dụng CashewDoc: Tải trực tiếp tệp PDF/Word lên S3 và đồng bộ Metadata vào RDS",
            ha='center', fontsize=8.5, color='#475569', style='italic')

    # Entities
    b_client = patches.FancyBboxPatch((3, 35), 23, 46, boxstyle="round,pad=1,rounding_size=2",
                                     facecolor="#DBEAFE", edgecolor="#2563EB", linewidth=2)
    ax.add_patch(b_client)
    ax.text(14.5, 66, "CLIENT\n(CashewDoc App)", ha='center', va='center', fontsize=10, fontweight='bold', color="#1E3A8A")
    ax.text(14.5, 48, "• Chọn file PDF/Docx\n• Lưu local SQLite cache\n• Nhận Pre-signed URL\n• Tải nhị phân lên S3\n• Đồng bộ trạng thái", 
            ha='center', va='center', fontsize=7.5, color="#1E40AF")

    b_api = patches.FancyBboxPatch((38, 55), 24, 26, boxstyle="round,pad=1,rounding_size=2",
                                  facecolor="#DCFCE7", edgecolor="#16A34A", linewidth=2)
    ax.add_patch(b_api)
    ax.text(50, 72, "BACKEND API\n(AWS ECS Fargate)", ha='center', va='center', fontsize=10, fontweight='bold', color="#166534")
    ax.text(50, 62, "• Xác thực JWT sinh viên\n• Sinh UUID v4 (UuidHelper)\n• Tạo Pre-signed PUT URL\n• Lưu metadata vào RDS", 
            ha='center', va='center', fontsize=7.5, color="#15803D")

    b_db = patches.FancyBboxPatch((38, 14), 24, 26, boxstyle="round,pad=1,rounding_size=2",
                                 facecolor="#E0E7FF", edgecolor="#4338CA", linewidth=2)
    ax.add_patch(b_db)
    ax.text(50, 31, "CLOUD DATABASE\n(Amazon RDS PostgreSQL)", ha='center', va='center', fontsize=9.5, fontweight='bold', color="#3730A3")
    ax.text(50, 21, "• Bảng documents (UUID v4)\n• Bảng attachments (S3 URI)\n• Bảng delete_logs (Audit)", 
            ha='center', va='center', fontsize=7.5, color="#4338CA")

    b_s3 = patches.FancyBboxPatch((74, 55), 23, 26, boxstyle="round,pad=1,rounding_size=2",
                                 facecolor="#FEF3C7", edgecolor="#D97706", linewidth=2)
    ax.add_patch(b_s3)
    ax.text(85.5, 72, "AMAZON S3\n(Object Storage)", ha='center', va='center', fontsize=10, fontweight='bold', color="#92400E")
    ax.text(85.5, 62, "• Lưu tệp nhị phân (.pdf)\n• Khóa: /uploads/uuid.pdf\n• Mã hóa AES-256 (KMS)\n• S3 Lifecycle Glacier", 
            ha='center', va='center', fontsize=7.5, color="#B45309")

    b_cdn = patches.FancyBboxPatch((74, 14), 23, 26, boxstyle="round,pad=1,rounding_size=2",
                                  facecolor="#F3E8FF", edgecolor="#7E22CE", linewidth=2)
    ax.add_patch(b_cdn)
    ax.text(85.5, 31, "CLOUDFRONT CDN\n(Edge Network)", ha='center', va='center', fontsize=9.5, fontweight='bold', color="#6B21A8")
    ax.text(85.5, 21, "• Cache tài liệu bài giảng\n• Phân phối toàn cầu <50ms\n• Signed URLs có TTL", 
            ha='center', va='center', fontsize=7.5, color="#7E22CE")

    # Arrows with steps
    arr_f = dict(arrowstyle="-|>", color="#1D4ED8", lw=2, mutation_scale=12)
    arr_s = dict(arrowstyle="-|>", color="#D97706", lw=2.5, mutation_scale=14)
    arr_g = dict(arrowstyle="-|>", color="#16A34A", lw=2, mutation_scale=12)
    arr_p = dict(arrowstyle="-|>", color="#7E22CE", lw=2, mutation_scale=12)

    # Step 1: Client -> API (Request Upload)
    ax.annotate('', xy=(37, 72), xytext=(27, 72), arrowprops=arr_f)
    ax.text(32, 74.5, "1. Gửi Metadata & Xin Upload", fontsize=7.5, color="#1E40AF", ha='center')

    # Step 2: API -> Client (Return Pre-signed URL)
    ax.annotate('', xy=(27, 63), xytext=(37, 63), arrowprops=arr_g)
    ax.text(32, 60, "2. Trả Pre-signed PUT URL (5m)", fontsize=7.5, color="#166534", ha='center')

    # Step 3: Client -> S3 (Direct Upload)
    ax.annotate('', xy=(73, 76), xytext=(27, 76), arrowprops=arr_s)
    ax.text(50, 79, "3. Upload trực tiếp file PDF/Word lên S3 (HTTP PUT - Băng thông tối đa)", fontsize=8, fontweight='bold', color="#D97706", ha='center')

    # Step 4: Client -> API (Confirm success)
    ax.annotate('', xy=(37, 57), xytext=(27, 57), arrowprops=arr_f)
    ax.text(32, 53, "4. Báo hoàn tất & ETag", fontsize=7.5, color="#1E40AF", ha='center')

    # Step 5: API -> RDS (Save Metadata)
    ax.annotate('', xy=(50, 41), xytext=(50, 54), arrowprops=arr_g)
    ax.text(51, 47, "5. Lưu Metadata (S3 Key, UUID)", fontsize=7.5, color="#166534")

    # Step 6: S3 -> CDN (Cache)
    ax.annotate('', xy=(85.5, 41), xytext=(85.5, 54), arrowprops=arr_p)
    ax.text(86.5, 47, "6. Cache tại Edge PoP", fontsize=7.5, color="#7E22CE")

    # Step 7: Client <- CDN (Fast Download)
    ax.annotate('', xy=(27, 38), xytext=(73, 38), arrowprops=arr_p)
    ax.text(50, 35, "7. Tải / Xem tài liệu bài giảng siêu tốc qua CloudFront Signed URL (<50ms)", fontsize=8, fontweight='bold', color="#7E22CE", ha='center')

    img_path = os.path.join(IMG_DIR, "cloud_data_flow_presigned.png")
    plt.tight_layout()
    plt.savefig(img_path, dpi=300, bbox_inches='tight', facecolor=fig.get_facecolor())
    plt.close()
    return img_path

# ==============================================================================
# PHẦN 2: HELPER FUNCTIONS FORMATTING DOCX
# ==============================================================================

def set_cell_background(cell, fill_hex):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{fill_hex}"/>')
    tcPr.append(shd)

def set_cell_margins(cell, top=100, bottom=100, left=150, right=150):
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = parse_xml(f'''
        <w:tcMar {nsdecls("w")}>
            <w:top w:w="{top}" w:type="dxa"/>
            <w:bottom w:w="{bottom}" w:type="dxa"/>
            <w:left w:w="{left}" w:type="dxa"/>
            <w:right w:w="{right}" w:type="dxa"/>
        </w:tcMar>
    ''')
    tcPr.append(tcMar)

def set_table_borders(table, color="CBD5E1"):
    tblPr = table._tbl.tblPr
    borders = parse_xml(f'''
        <w:tblBorders {nsdecls("w")}>
            <w:top w:val="single" w:sz="6" w:space="0" w:color="{color}"/>
            <w:bottom w:val="single" w:sz="6" w:space="0" w:color="{color}"/>
            <w:insideH w:val="single" w:sz="4" w:space="0" w:color="{color}"/>
            <w:insideV w:val="none"/>
            <w:left w:val="none"/>
            <w:right w:val="none"/>
        </w:tblBorders>
    ''')
    tblPr.append(borders)

def add_callout(doc, text, title=None, border_color="0284C7", bg_color="F0F9FF"):
    tbl = doc.add_table(rows=1, cols=1)
    tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    cell = tbl.cell(0, 0)
    set_cell_background(cell, bg_color)
    set_cell_margins(cell, top=120, bottom=120, left=180, right=180)
    
    tcPr = cell._tc.get_or_add_tcPr()
    borders = parse_xml(f'''
        <w:tcBorders {nsdecls("w")}>
            <w:left w:val="single" w:sz="24" w:space="0" w:color="{border_color}"/>
            <w:top w:val="none"/>
            <w:bottom w:val="none"/>
            <w:right w:val="none"/>
        </w:tcBorders>
    ''')
    tcPr.append(borders)
    
    p = cell.paragraphs[0]
    p.paragraph_format.space_before = Pt(3)
    p.paragraph_format.space_after = Pt(3)
    p.paragraph_format.line_spacing = 1.15
    if title:
        run_title = p.add_run(f"📌 {title}\n")
        run_title.font.name = "Calibri"
        run_title.font.size = Pt(10.5)
        run_title.font.bold = True
        run_title.font.color.rgb = RGBColor(15, 76, 129)
    run_text = p.add_run(text)
    run_text.font.name = "Calibri"
    run_text.font.size = Pt(10)
    run_text.font.color.rgb = RGBColor(51, 65, 85)
    
    empty_p = doc.add_paragraph()
    empty_p.paragraph_format.space_before = Pt(0)
    empty_p.paragraph_format.space_after = Pt(4)

def format_table_header(row, col_widths, titles):
    for i, title in enumerate(titles):
        cell = row.cells[i]
        set_cell_background(cell, "1E3A8A")
        set_cell_margins(cell, top=110, bottom=110, left=140, right=140)
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.LEFT
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(0)
        run = p.add_run(title)
        run.font.name = "Calibri"
        run.font.size = Pt(10)
        run.font.bold = True
        run.font.color.rgb = RGBColor(255, 255, 255)
        if col_widths and i < len(col_widths):
            cell.width = col_widths[i]

def add_table_row(row, col_widths, values, is_even=False):
    fill = "F8FAFC" if is_even else "FFFFFF"
    for i, val in enumerate(values):
        cell = row.cells[i]
        set_cell_background(cell, fill)
        set_cell_margins(cell, top=70, bottom=70, left=120, right=120)
        p = cell.paragraphs[0]
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(0)
        p.paragraph_format.line_spacing = 1.15
        run = p.add_run(val)
        run.font.name = "Calibri"
        run.font.size = Pt(9.5)
        run.font.color.rgb = RGBColor(30, 41, 59)
        if col_widths and i < len(col_widths):
            cell.width = col_widths[i]

def add_caption(doc, text):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(3)
    p.paragraph_format.space_after = Pt(10)
    run = p.add_run(text)
    run.font.name = "Calibri"
    run.font.size = Pt(9.5)
    run.font.italic = True
    run.font.color.rgb = RGBColor(100, 116, 139)

def add_sec_h1(doc, title):
    h = doc.add_heading(level=1)
    h.paragraph_format.space_before = Pt(16)
    h.paragraph_format.space_after = Pt(6)
    h.paragraph_format.keep_with_next = True
    run = h.add_run(title)
    run.font.name = "Calibri"
    run.font.size = Pt(15)
    run.font.bold = True
    run.font.color.rgb = RGBColor(30, 58, 138)
    return h

def add_sec_h2(doc, title):
    h = doc.add_heading(level=2)
    h.paragraph_format.space_before = Pt(12)
    h.paragraph_format.space_after = Pt(4)
    h.paragraph_format.keep_with_next = True
    run = h.add_run(title)
    run.font.name = "Calibri"
    run.font.size = Pt(12.5)
    run.font.bold = True
    run.font.color.rgb = RGBColor(2, 132, 199)
    return h

def add_sec_h3(doc, title):
    h = doc.add_heading(level=3)
    h.paragraph_format.space_before = Pt(8)
    h.paragraph_format.space_after = Pt(3)
    h.paragraph_format.keep_with_next = True
    run = h.add_run(title)
    run.font.name = "Calibri"
    run.font.size = Pt(11)
    run.font.bold = True
    run.font.color.rgb = RGBColor(15, 23, 42)
    return h

def add_body_p(doc, text):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(5)
    p.paragraph_format.line_spacing = 1.2
    run = p.add_run(text)
    run.font.name = "Calibri"
    run.font.size = Pt(10.5)
    run.font.color.rgb = RGBColor(51, 65, 85)
    return p

def add_bullet_p(doc, bold_prefix, text):
    p = doc.add_paragraph(style='List Bullet')
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(3)
    p.paragraph_format.line_spacing = 1.15
    run_b = p.add_run(bold_prefix)
    run_b.font.name = "Calibri"
    run_b.font.size = Pt(10)
    run_b.font.bold = True
    run_b.font.color.rgb = RGBColor(15, 23, 42)
    
    run_t = p.add_run(text)
    run_t.font.name = "Calibri"
    run_t.font.size = Pt(10)
    run_t.font.color.rgb = RGBColor(51, 65, 85)
    return p

def add_code_block(doc, code_text):
    tbl = doc.add_table(rows=1, cols=1)
    tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    cell = tbl.cell(0, 0)
    set_cell_background(cell, "1E293B")
    set_cell_margins(cell, top=100, bottom=100, left=150, right=150)
    
    tcPr = cell._tc.get_or_add_tcPr()
    borders = parse_xml(f'''
        <w:tcBorders {nsdecls("w")}>
            <w:left w:val="single" w:sz="16" w:space="0" w:color="38BDF8"/>
            <w:top w:val="none"/>
            <w:bottom w:val="none"/>
            <w:right w:val="none"/>
        </w:tcBorders>
    ''')
    tcPr.append(borders)
    
    p = cell.paragraphs[0]
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(2)
    p.paragraph_format.line_spacing = 1.05
    run = p.add_run(code_text)
    run.font.name = "Consolas"
    run.font.size = Pt(9)
    run.font.color.rgb = RGBColor(241, 245, 249)
    
    empty_p = doc.add_paragraph()
    empty_p.paragraph_format.space_before = Pt(0)
    empty_p.paragraph_format.space_after = Pt(4)

# ==============================================================================
# PHẦN 3: XÂY DỰNG TÀI LIỆU DOCX DỰA TRÊN BÀI THỰC HÀNH 1
# ==============================================================================

def build_cloud_doc():
    print("-> Đang vẽ các sơ đồ kiến trúc Cloud 300 DPI...")
    arch_img = generate_traditional_vs_cloud_arch_diagram()
    flow_img = generate_cloud_data_flow_diagram()

    print("-> Đang khởi tạo tài liệu Word: phan_tich_va_lap_phuong_an.docx...")
    doc = Document()
    
    # Thiết lập lề chuẩn trang A4
    for section in doc.sections:
        section.top_margin = Inches(0.9)
        section.bottom_margin = Inches(0.9)
        section.left_margin = Inches(1.0)
        section.right_margin = Inches(1.0)
        section.page_width = Inches(8.27)
        section.page_height = Inches(11.69)

    # --------------------------------------------------------------------------
    # TRANG TIÊU ĐỀ / BÌA BÁO CÁO HỌC THUẬT PTIT
    # --------------------------------------------------------------------------
    p_inst = doc.add_paragraph()
    p_inst.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_inst.paragraph_format.space_before = Pt(10)
    p_inst.paragraph_format.space_after = Pt(2)
    r_inst = p_inst.add_run("HỌC VIỆN CÔNG NGHỆ BƯU CHÍNH VIỄN THÔNG (PTIT)\n")
    r_inst.font.name = "Calibri"
    r_inst.font.size = Pt(12)
    r_inst.font.bold = True
    r_inst.font.color.rgb = RGBColor(30, 58, 138)
    
    r_dept = p_inst.add_run("KHOA CÔNG NGHỆ THÔNG TIN - BỘ MÔN CÔNG NGHỆ PHẦN MỀM & HỆ THỐNG MẠNG\n")
    r_dept.font.name = "Calibri"
    r_dept.font.size = Pt(11)
    r_dept.font.bold = True
    r_dept.font.color.rgb = RGBColor(71, 85, 105)

    p_line = doc.add_paragraph()
    p_line.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_line.paragraph_format.space_after = Pt(26)
    r_line = p_line.add_run("─────────── ★ ───────────")
    r_line.font.color.rgb = RGBColor(148, 163, 184)

    p_title = doc.add_paragraph()
    p_title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_title.paragraph_format.space_after = Pt(12)
    r_title = p_title.add_run("BÁO CÁO PHÂN TÍCH VÀ LẬP PHƯƠNG ÁN\n")
    r_title.font.name = "Calibri"
    r_title.font.size = Pt(22)
    r_title.font.bold = True
    r_title.font.color.rgb = RGBColor(30, 58, 138)

    p_sub = doc.add_paragraph()
    p_sub.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_sub.paragraph_format.space_after = Pt(24)
    r_sub = p_sub.add_run("CHUYỂN ĐỔI MÔ HÌNH LƯU TRỮ VÀ TÍCH HỢP ĐIỆN TOÁN ĐÁM MÂY (CLOUD)\nCHO ỨNG DỤNG BÀI THỰC HÀNH 1 - QUẢN LÝ TÀI LIỆU HỌC TẬP (CashewDoc)\n")
    r_sub.font.name = "Calibri"
    r_sub.font.size = Pt(13.5)
    r_sub.font.bold = True
    r_sub.font.color.rgb = RGBColor(2, 132, 199)

    add_callout(doc, 
        "Báo cáo kỹ thuật phân tích trực tiếp trên mã nguồn và kiến trúc của Ứng dụng Quản lý Tài liệu Học tập (CashewDoc - Bài thực hành 1 môn Lập trình Thiết bị Di động); chỉ rõ các thành phần hiện có (Flutter Presentation, Clean Service Layer, SQLite FFI Database, Local File Sandbox); nhận diện các giới hạn cố hữu khi chỉ vận hành trên thiết bị cục bộ; đề xuất phương án tích hợp Điện toán Đám mây (Amazon S3, CloudFront CDN, RDS PostgreSQL, ECS Fargate); thiết kế sơ đồ luồng dữ liệu Direct-to-S3 Upload với Pre-signed URL; và đánh giá toàn diện tác động về an toàn bảo mật, chi phí tối ưu (Pay-as-you-go) cùng hiệu suất tải bài giảng quy mô trường học.",
        title="TÓM TẮT ĐỀ TÀI (EXECUTIVE SUMMARY)",
        border_color="0284C7", bg_color="F0F9FF"
    )

    info_tbl = doc.add_table(rows=6, cols=2)
    info_tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(info_tbl, "E2E8F0")
    col_w = [Inches(2.4), Inches(4.2)]
    
    meta_data = [
        ("Môn học:", "Lập trình Thiết bị Di động & Kiến trúc Hệ thống"),
        ("Đối tượng nghiên cứu thực tế:", "Bài thực hành 1: Ứng dụng Quản lý Tài liệu Học tập (CashewDoc)"),
        ("Sinh viên thực hiện:", "Thu Hoài (Username GitHub: ThuHoai10)"),
        ("Mã nguồn dự án thực hành:", "https://github.com/ThuHoai10/TH1 (Branch main)"),
        ("Mô hình đám mây đề xuất:", "Public Cloud (AWS S3 Object Storage + CloudFront + RDS)"),
        ("Tệp tài liệu báo cáo:", "phan_tich_va_lap_phuong_an.docx"),
    ]
    for idx, (lbl, val) in enumerate(meta_data):
        row = info_tbl.rows[idx]
        cell_lbl, cell_val = row.cells[0], row.cells[1]
        set_cell_background(cell_lbl, "F8FAFC")
        set_cell_background(cell_val, "FFFFFF")
        set_cell_margins(cell_lbl, top=60, bottom=60, left=100, right=100)
        set_cell_margins(cell_val, top=60, bottom=60, left=100, right=100)
        
        p0 = cell_lbl.paragraphs[0]
        r0 = p0.add_run(lbl)
        r0.font.name = "Calibri"
        r0.font.size = Pt(10)
        r0.font.bold = True
        r0.font.color.rgb = RGBColor(30, 41, 59)
        
        p1 = cell_val.paragraphs[0]
        r1 = p1.add_run(val)
        r1.font.name = "Calibri"
        r1.font.size = Pt(10)
        r1.font.color.rgb = RGBColor(71, 85, 105)
        
        cell_lbl.width = col_w[0]
        cell_val.width = col_w[1]

    doc.add_page_break()

    # --------------------------------------------------------------------------
    # MỤC LỤC
    # --------------------------------------------------------------------------
    add_sec_h1(doc, "MỤC LỤC BÁO CÁO")
    toc_items = [
        "1. LIỆT KÊ VÀ PHÂN TÍCH CÁC THÀNH PHẦN CỐT LÕI CỦA ỨNG DỤNG BÀI THỰC HÀNH 1 (CashewDoc)",
        "    1.1. Tầng Giao diện Người dùng (Frontend / Presentation Layer)",
        "    1.2. Tầng Nghiệp vụ & Dịch vụ (Backend / Clean Application Service Layer)",
        "    1.3. Tầng Cơ sở Dữ liệu (Database Layer - Local SQLite FFI)",
        "    1.4. Tầng Lưu trữ Tệp nhị phân (File Storage Layer - Local Device Sandbox)",
        "    1.5. Ma trận tương tác và luồng dữ liệu hiện tại trong bài thực hành",
        "2. XÁC ĐỊNH CÁC ĐIỂM NGHẼN VÀ HẠN CHẾ CỦA HỆ THỐNG TRÊN HẠ TẦNG TRUYỀN THỐNG CỤC BỘ",
        "    2.1. Hạn chế cô lập trên một thiết bị đơn lẻ (Single Device Island)",
        "    2.2. Nguy cơ mất mát dữ liệu học tập vĩnh viễn (Single Point of Failure - SPOF)",
        "    2.3. Cạn kiệt bộ nhớ trong của thiết bị di động (Local Storage Depletion)",
        "    2.4. Rào cản chia sẻ tài liệu và cộng tác học tập từ xa (Lack of Collaboration)",
        "    2.5. Hạn chế về an toàn thông tin và thiếu mã hóa dữ liệu tĩnh (At-Rest Encryption)",
        "    2.6. Điểm nghẽn băng thông và chi phí nếu chuyển sang máy chủ tự dựng On-Premise",
        "3. LỰA CHỌN MÔ HÌNH TRIỂN KHAI CLOUD VÀ CÁC DỊCH VỤ CỤ THỂ CHO BÀI THỰC HÀNH",
        "    3.1. So sánh các mô hình Đám mây (Public vs. Private vs. Hybrid Cloud)",
        "    3.2. Lựa chọn Mô hình Public Cloud kết hợp Kiến trúc Cloud-Enhanced Offline-First",
        "    3.3. Dịch vụ Lưu trữ Đối tượng: Amazon S3 (Simple Storage Service)",
        "    3.4. Dịch vụ Mạng Phân phối Nội dung: Amazon CloudFront CDN",
        "    3.5. Dịch vụ Cơ sở Dữ liệu Đám mây: Amazon RDS PostgreSQL (Multi-AZ)",
        "    3.6. Dịch vụ Tính toán Backend: Containerized AWS ECS Fargate",
        "    3.7. Dịch vụ Bảo mật & Mã hóa Khóa: AWS KMS & IAM Roles",
        "4. THIẾT KẾ SƠ ĐỒ KIẾN TRÚC TÍCH HỢP CLOUD VÀ LUỒNG DỮ LIỆU TỐI ƯU CHO CASHEWDOC",
        "    4.1. Sơ đồ Kiến trúc So sánh Tổng quan: CashewDoc Hiện Tại vs. Tích Hợp Cloud",
        "    4.2. Sơ đồ Luồng Dữ liệu: Direct-to-S3 Upload qua Pre-signed URL",
        "    4.3. Mô tả Quy trình Tải lên Tệp Bài giảng (Direct Upload Workflow) 6 Bước",
        "    4.4. Mô tả Quy trình Tải xuống & Xem trước Tài liệu (Preview via CDN)",
        "    4.5. Thuật toán Đồng bộ 2 Chiều (Bidirectional Sync) dựa trên UUID v4 và DeleteLogs",
        "5. ĐÁNH GIÁ TÁC ĐỘNG VỀ BẢO MẬT, CHI PHÍ VÀ HIỆU SUẤT SAU KHI TÍCH HỢP",
        "    5.1. Đánh giá Tác động về An toàn & Bảo mật (Security & Compliance)",
        "    5.2. Đánh giá Tác động về Chi phí Đầu tư & Vận hành (Cost Optimization cho Sinh viên)",
        "    5.3. Đánh giá Tác động về Hiệu suất & Độ sẵn sàng (Performance, Latency & High Availability)",
        "    5.4. Bảng Tổng hợp Đối chiếu Trước và Sau Chuyển đổi",
        "KẾT LUẬN & ĐỀ XUẤT LỘ TRÌNH TRIỂN KHAI CHO DỰ ÁN"
    ]
    for item in toc_items:
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(1)
        p.paragraph_format.space_after = Pt(2)
        r = p.add_run(item)
        r.font.name = "Calibri"
        r.font.size = Pt(10)
        if item.startswith("1.") or item.startswith("2.") or item.startswith("3.") or item.startswith("4.") or item.startswith("5.") or item.startswith("KẾT"):
            r.font.bold = True
            r.font.color.rgb = RGBColor(30, 58, 138)
        else:
            r.font.color.rgb = RGBColor(51, 65, 85)

    doc.add_page_break()

    # --------------------------------------------------------------------------
    # BƯỚC 1: LIỆT KÊ VÀ PHÂN TÍCH CÁC THÀNH PHẦN CỐT LÕI
    # --------------------------------------------------------------------------
    add_sec_h1(doc, "1. LIỆT KÊ VÀ PHÂN TÍCH CÁC THÀNH PHẦN CỐT LÕI CỦA ỨNG DỤNG BÀI THỰC HÀNH 1 (CashewDoc)")
    
    add_body_p(doc, 
        "Dựa trên mã nguồn thực tế đã xây dựng trong Bài thực hành 1 (dự án CashewDoc), ứng dụng quản lý tài liệu học tập của sinh viên được tổ chức theo kiến trúc Clean Architecture 4 tầng nghiêm ngặt. Hệ thống hiện đang vận hành theo mô hình Client-Centric / Offline-First cục bộ với 4 thành phần trụ cột cốt lõi sau:"
    )

    add_sec_h2(doc, "1.1. Tầng Giao diện Người dùng (Frontend / Presentation Layer)")
    add_bullet_p(doc, "Vị trí trong mã nguồn: ", "Thư mục 'lib/presentation/' với các màn hình chính: HomeScreen, DocumentFormScreen, DocumentDetailScreen, DashboardScreen, TrashScreen và các widget DocumentCard, StatusBadge.")
    add_bullet_p(doc, "Trách nhiệm chính: ", 
        "• Trực quan hóa dữ liệu học tập: Danh sách tài liệu phân loại theo màu sắc môn học, thẻ trạng thái tiến độ học tập (Chưa học, Đang học, Hoàn thành), biểu đồ thống kê cơ cấu tài liệu trên Dashboard.\n"
        "• Thu nhận thông tin đầu vào: Biểu mẫu nhập Tiêu đề, Mô tả, Môn học, kèm bộ chọn tệp đính kèm (File Picker) cho phép sinh viên tải các tệp thực tế (.pdf, .docx, .pptx, .xlsx, .zip, hình ảnh).\n"
        "• Tìm kiếm & Lọc thời gian thực: Thanh tìm kiếm từ khóa không phân biệt hoa thường và các chip lọc (Filter Chips) theo môn học và trạng thái tiến độ."
    )
    add_bullet_p(doc, "Quản lý trạng thái (State Management): ", 
        "Sử dụng lớp 'DocumentController' (kế thừa ChangeNotifier). Controller tự động đăng ký lắng nghe (listen) luồng dữ liệu Reactive Stream từ tầng Service để render lại giao diện tức thì khi có sự kiện thay đổi dữ liệu."
    )

    # Chèn ảnh chụp giao diện thực tế của bài thực hành
    scr_home = os.path.join(IMG_DIR, "android_emulator_screen.png")
    if os.path.exists(scr_home):
        doc.add_paragraph()
        doc.add_picture(scr_home, width=Inches(3.8))
        add_caption(doc, "Hình 1.1: Giao diện Màn hình Chính (HomeScreen) của Ứng dụng CashewDoc trên Máy ảo Android")

    add_sec_h2(doc, "1.2. Tầng Nghiệp vụ & Dịch vụ (Backend / Clean Application Service Layer)")
    add_bullet_p(doc, "Vị trí trong mã nguồn: ", "Thư mục 'lib/services/' bao gồm: DocumentService.dart, SubjectService.dart, SearchService.dart.")
    add_bullet_p(doc, "Kiểm định nghiệp vụ (Validation): ", 
        "Kiểm tra tính hợp lệ dữ liệu trước khi lưu: Bắt buộc tiêu đề tài liệu không được để trống (ném ra ArgumentError nếu rỗng), bắt buộc chọn môn học hợp lệ, phân loại tài liệu thuộc danh mục chuẩn (Bài giảng, Bài tập, Tham khảo, Đề thi)."
    )
    add_bullet_p(doc, "Định danh phân tán bằng UUID v4: ", 
        "Sử dụng tiện ích UuidHelper (lib/core/utils/uuid_helper.dart) để tự động sinh khóa chính ngẫu nhiên 128-bit cho mọi tài liệu, môn học, tệp đính kèm và bản ghi nhật ký xóa. Điều này triệt tiêu xung đột ID và là tiền đề vững chắc để đồng bộ lên Cloud."
    )
    add_bullet_p(doc, "Máy trạng thái (State Machine) & Xóa mềm (Soft-Delete): ", 
        "Điều khiển vòng lặp tiến độ 1-tap: Chưa học -> Đang học -> Đã hoàn thành -> Chưa học. Điều phối quy trình xóa mềm: Cập nhật cờ 'is_deleted = 1' và tự động ghi một bản ghi lịch sử vào bảng 'delete_logs' để phục vụ màn hình Thùng rác (TrashScreen) và Khôi phục (Restore)."
    )

    add_sec_h2(doc, "1.3. Tầng Cơ sở Dữ liệu (Database Layer - Local SQLite FFI)")
    add_bullet_p(doc, "Vị trí trong mã nguồn: ", "Thư mục 'lib/data/datasources/local/app_database.dart' và các lớp truy vấn DAO trong 'lib/data/daos/'.")
    add_bullet_p(doc, "Công nghệ CSDL: ", "Hệ quản trị CSDL quan hệ SQLite nhúng cục bộ (thư viện sqflite/sqflite_common_ffi), mở khóa ngoại (PRAGMA foreign_keys = ON) và quản lý Transaction an toàn.")
    add_bullet_p(doc, "Cấu trúc các bảng dữ liệu cốt lõi: ", 
        "• Bảng 'documents': Khóa chính document_pk (TEXT UUID), title, description, subject_fk, document_type, status, date_time_created, date_time_modified, is_deleted.\n"
        "• Bảng 'subjects': Khóa chính subject_pk (TEXT UUID), subject_name, color_code, teacher_name, description.\n"
        "• Bảng 'attachments': Khóa chính attachment_pk (TEXT UUID), document_fk (Khóa ngoại), file_name, file_path, file_size, file_type, created_at.\n"
        "• Bảng 'delete_logs': Khóa chính log_pk (TEXT UUID), entity_pk, entity_type, date_time_deleted."
    )

    add_sec_h2(doc, "1.4. Tầng Lưu trữ Tệp nhị phân (File Storage Layer - Local Device Sandbox)")
    add_bullet_p(doc, "Cơ chế lưu trữ hiện tại: ", 
        "Khi sinh viên chọn một tệp tài liệu học tập (ví dụ file Slide bài giảng PDF hoặc đề thi DOCX), tệp được sao chép và lưu trữ trực tiếp vào thư mục phân vùng ứng dụng của điện thoại (Android App Sandbox / Internal Storage)."
    )
    add_bullet_p(doc, "Liên kết CSDL: ", 
        "CSDL chỉ lưu đường dẫn tệp ('file_path' trỏ tới file trên bộ nhớ máy) cùng dung lượng tệp ('file_size' theo bytes). Nội dung nhị phân không được lưu vào SQLite để tránh làm phình to file database."
    )

    scr_detail = os.path.join(IMG_DIR, "detail_with_attachment.png")
    if os.path.exists(scr_detail):
        doc.add_paragraph()
        doc.add_picture(scr_detail, width=Inches(3.8))
        add_caption(doc, "Hình 1.2: Chi tiết Tài liệu kèm Tệp Đính kèm Vật lý được Quản lý Cục bộ trên Thiết bị")

    add_sec_h2(doc, "1.5. Bảng Tổng Hợp 4 Thành Phần Hệ Thống CashewDoc Hiện Tại")

    comp_tbl = doc.add_table(rows=5, cols=4)
    comp_tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(comp_tbl, "CBD5E1")
    comp_w = [Inches(1.5), Inches(1.8), Inches(2.2), Inches(1.5)]
    format_table_header(comp_tbl.rows[0], comp_w, ["Thành Phần", "Vị Trí Mã Nguồn", "Trách Nhiệm Chính", "Hạ Tầng Vận Hành Hiện Tại"])
    
    comp_data = [
        ("Frontend (Presentation)", "lib/presentation/ (Screens, Widgets)", "Hiển thị giao diện, bộ chọn tệp đính kèm, tìm kiếm, lọc, lắng nghe Streams", "Ứng dụng Flutter trên điện thoại sinh viên"),
        ("Backend (Service Logic)", "lib/services/ (DocService, SearchService)", "Validation dữ liệu, sinh UUID v4, điều khiển máy trạng thái, xóa mềm ghi log", "Chạy trực tiếp trong tiến trình (In-Process) trên di động"),
        ("Database (Metadata)", "lib/data/ (AppDatabase, DAOs, Models)", "Lưu trữ metadata bảng documents, subjects, attachments, delete_logs", "CSDL SQLite cục bộ trong bộ nhớ máy"),
        ("File Storage (Binary)", "lib/data/daos/ (Attachment engine)", "Lưu trữ tệp nhị phân vật lý (.pdf, .docx, .pptx, .xlsx, .zip)", "Bộ nhớ ổ đĩa điện thoại (Android App Sandbox)"),
    ]
    for idx, r_vals in enumerate(comp_data):
        add_table_row(comp_tbl.rows[idx + 1], comp_w, r_vals, is_even=(idx % 2 == 1))

    doc.add_paragraph()

    # --------------------------------------------------------------------------
    # BƯỚC 2: ĐIỂM NGHẼN VÀ HẠN CHẾ CỦA HẠ TẦNG HIỆN TẠI
    # --------------------------------------------------------------------------
    add_sec_h1(doc, "2. XÁC ĐỊNH CÁC ĐIỂM NGHẼN VÀ HẠN CHẾ CỦA HỆ THỐNG TRÊN HẠ TẦNG TRUYỀN THỐNG CỤC BỘ")
    
    add_body_p(doc, 
        "Mặc dù kiến trúc cục bộ của CashewDoc mang lại tốc độ phản hồi 0ms và khả năng hoạt động tốt khi không có mạng (Offline-First), khi đưa vào sử dụng thực tế trong môi trường học tập, hệ thống bộc lộ 6 điểm nghẽn và hạn chế cố hữu sau:"
    )

    add_sec_h2(doc, "2.1. Hạn chế cô lập trên một thiết bị đơn lẻ (Single Device Island)")
    add_bullet_p(doc, "Thiếu đồng bộ đa thiết bị (No Multi-Device Sync): ", 
        "Hiện tại, toàn bộ dữ liệu tài liệu và tệp đính kèm chỉ tồn tại trên chiếc điện thoại di động mà sinh viên đang dùng. Khi sinh viên muốn sử dụng Laptop để học bài hoặc máy tính bảng để đọc slide, không có cách nào truy cập vào kho tài liệu đã lưu trên điện thoại nếu không cắm cáp USB chép dữ liệu thủ công."
    )

    add_sec_h2(doc, "2.2. Nguy cơ mất mát dữ liệu học tập vĩnh viễn (Single Point of Failure - SPOF)")
    add_bullet_p(doc, "Rủi ro mất máy hoặc hỏng phần cứng: ", 
        "Do không có cơ chế sao lưu tự động (Cloud Backup), nếu điện thoại của sinh viên bị rơi vỡ, hỏng bộ nhớ flash, bị mất cắp hoặc sinh viên vô tình gỡ cài đặt ứng dụng (Uninstall), toàn bộ ghi chú học tập, tài liệu ôn thi và tệp đính kèm tích lũy qua các kỳ học sẽ biến mất hoàn toàn mà không thể khôi phục."
    )

    add_sec_h2(doc, "2.3. Cạn kiệt bộ nhớ trong của thiết bị di động (Local Storage Depletion)")
    add_bullet_p(doc, "Áp lực dung lượng đĩa di động: ", 
        "Các tệp giáo trình PDF, slide bài giảng môn học (chứa nhiều hình ảnh chất lượng cao) hoặc video bài giảng thường có dung lượng từ 30MB đến 150MB mỗi tệp. Khi lưu trữ hàng chục môn học qua các năm, bộ nhớ trong của điện thoại sẽ nhanh chóng bị đầy ('Insufficient Storage'), gây ảnh hưởng tới hoạt động của toàn bộ hệ điều hành điện thoại."
    )

    add_sec_h2(doc, "2.4. Rào cản chia sẻ tài liệu và cộng tác học tập từ xa (Lack of Collaboration)")
    add_bullet_p(doc, "Không thể chia sẻ liên kết tài liệu: ", 
        "Trong học tập theo nhóm (Teamwork), sinh viên không thể chia sẻ đường link tài liệu bài giảng cho bạn cùng lớp. Mọi thao tác chia sẻ đều phải thực hiện ngoài luồng qua các ứng dụng nhắn tin khác, gây phân mảnh và mất tính quản lý tập trung."
    )

    add_sec_h2(doc, "2.5. Hạn chế về an toàn thông tin và thiếu mã hóa dữ liệu tĩnh (At-Rest Encryption)")
    add_bullet_p(doc, "Lưu trữ tệp thô không mã hóa: ", 
        "Các tệp tài liệu trong bộ nhớ máy hiện đang được lưu dưới dạng file thông thường. Bất kỳ ứng dụng nào có quyền truy cập bộ nhớ ngoài hoặc khi thiết bị bị Root/Jailbreak đều có thể đọc trộm các tài liệu ôn tập và đề thi nhạy cảm."
    )

    add_sec_h2(doc, "2.6. Điểm nghẽn băng thông và chi phí nếu chuyển sang máy chủ tự dựng On-Premise")
    add_bullet_p(doc, "Nghẽn cổ chai tải tệp (Bandwidth Chokepoint): ", 
        "Nếu nhà trường giải quyết bài toán bằng cách dựng máy chủ On-Premise truyền thống trong phòng server trường học: Khi đến mùa thi, hàng nghìn sinh viên cùng truy cập tải slide và nộp bài tập lớn cùng lúc sẽ làm nghẽn đường truyền mạng của trường, cạn kiệt băng thông và làm sập máy chủ ứng dụng."
    )
    add_bullet_p(doc, "Gánh nặng chi phí phần cứng (CapEx): ", 
        "Nhà trường phải đầu tư chi phí lớn ban đầu để mua máy chủ, ổ đĩa lưu trữ, hệ thống điều hòa và duy trì đội ngũ kỹ thuật trực 24/7."
    )

    # --------------------------------------------------------------------------
    # BƯỚC 3: LỰA CHỌN MÔ HÌNH CLOUD VÀ DỊCH VỤ CỤ THỂ
    # --------------------------------------------------------------------------
    add_sec_h1(doc, "3. LỰA CHỌN MÔ HÌNH TRIỂN KHAI CLOUD VÀ CÁC DỊCH VỤ CỤ THỂ CHO BÀI THỰC HÀNH")

    add_sec_h2(doc, "3.1. So Sánh Các Mô Hình Đám Mây (Public vs. Private vs. Hybrid Cloud)")
    add_body_p(doc, 
        "Để giải quyết triệt để 6 hạn chế nêu trên cho ứng dụng CashewDoc, chúng tôi tiến hành đánh giá 3 mô hình triển khai điện toán đám mây:"
    )

    cloud_tbl = doc.add_table(rows=4, cols=4)
    cloud_tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(cloud_tbl, "CBD5E1")
    c_w = [Inches(1.4), Inches(1.8), Inches(2.0), Inches(1.8)]
    format_table_header(cloud_tbl.rows[0], c_w, ["Mô Hình Đám Mây", "Đặc Điểm Vận Hành", "Ưu Điểm Cốt Lõi", "Đánh Giá Áp Dụng Cho CashewDoc"])
    
    cloud_model_data = [
        ("Public Cloud (AWS / GCP / Azure)", "Hạ tầng thuộc sở hữu của nhà cung cấp Cloud hàng đầu thế giới, chia sẻ tài nguyên an toàn đa khách hàng", "Khả năng co giãn vô hạn, thanh toán theo dung lượng thực tế (Pay-as-you-go), độ bền 11 số 9, không tốn chi phí bảo trì phần cứng", "LỰA CHỌN TỐI ƯU NHẤT: Rất phù hợp với quy mô sinh viên, tiết kiệm chi phí và triển khai nhanh chóng"),
        ("Private Cloud (On-Premises Cloud)", "Hạ tầng ảo hóa riêng biệt đặt tại trung tâm dữ liệu của trường học (OpenStack, VMware vSphere)", "Kiểm soát vật lý tuyệt đối trong mạng nội bộ", "KHÔNG KHẢ THI: Chi phí đầu tư máy chủ ban đầu quá đắt đỏ, tốn nhân lực quản trị và khó mở rộng quy mô linh hoạt"),
        ("Hybrid Cloud (Lai ghép)", "Kết hợp giữa máy chủ nội bộ trường học và Public Cloud (lưu trữ tệp lớn trên S3)", "Tận dụng hạ tầng cũ sẵn có của trường", "PHÙ HỢP CHO GIAI ĐOẠN QUÁ ĐỘ: Thích hợp nếu nhà trường đã có sẵn hệ thống máy chủ CSDL sinh viên nội bộ"),
    ]
    for idx, r_vals in enumerate(cloud_model_data):
        add_table_row(cloud_tbl.rows[idx + 1], c_w, r_vals, is_even=(idx % 2 == 1))

    doc.add_paragraph()

    add_sec_h2(doc, "3.2. Lựa Chọn Mô Hình: Public Cloud Kết Hợp Kiến Trúc Cloud-Enhanced Offline-First")
    add_callout(doc, 
        "QUYẾT ĐỊNH KIẾN TRÚC: Chúng tôi đề xuất mô hình 'Cloud-Enhanced Offline-First' trên nền tảng Public Cloud (Amazon Web Services - AWS).\n"
        "• Trên thiết bị di động: Vẫn duy trì 100% CSDL SQLite FFI cục bộ để đảm bảo tốc độ phản hồi 0ms và khả năng xem tài liệu khi không có mạng (bảo tồn tinh hoa Cashew).\n"
        "• Trên đám mây: Tích hợp Amazon S3 để lưu trữ tệp nhị phân vĩnh viễn, kết hợp Amazon RDS PostgreSQL để đồng bộ metadata đa thiết bị thông qua chuỗi UUID v4 và bảng delete_logs đã có sẵn!",
        title="CHIẾN LƯỢC KIẾN TRÚC ĐỘT PHÁ CHO BÀI THỰC HÀNH",
        border_color="16A34A", bg_color="F0FDF4"
    )

    add_sec_h2(doc, "3.3. Dịch Vụ Lưu Trữ Đối Tượng: Amazon S3 (Simple Storage Service)")
    add_bullet_p(doc, "Lý do lựa chọn cho CashewDoc: ", 
        "• Độ bền dữ liệu 99.999999999% (11 số 9): Dữ liệu bài giảng được nhân bản tự động qua tối thiểu 3 Trung tâm Dữ liệu độc lập (AZs). Sinh viên không bao giờ lo mất tài liệu.\n"
        "• Cơ chế Pre-signed URLs: Cho phép ứng dụng di động tải trực tiếp tệp PDF/Word lên S3 mà không cần đi qua máy chủ trung gian, giải phóng 100% băng thông server.\n"
        "• Tối ưu chi phí bằng S3 Lifecycle Policies: Tự động chuyển các tài liệu của kỳ học trước sang lớp lưu trữ S3 Glacier Deep Archive (giá chỉ 0.00099 USD/GB/tháng) giúp tiết kiệm đến 95% chi phí."
    )

    add_sec_h2(doc, "3.4. Dịch Vụ Mạng Phân Phối Nội Dung: Amazon CloudFront CDN")
    add_bullet_p(doc, "Lý do lựa chọn: ", 
        "Mạng lưới hơn 600 điểm PoP biên toàn cầu lưu tạm (Cache) các tài liệu bài giảng phổ biến. Khi sinh viên tải slide bài giảng, file được truyền từ PoP gần nhất với độ trễ dưới 50ms, tốc độ tải gấp 3 - 5 lần so với tải từ máy chủ thông thường."
    )

    add_sec_h2(doc, "3.5. Dịch Vụ Cơ Sở Dữ Liệu Đám Mây: Amazon RDS for PostgreSQL")
    add_bullet_p(doc, "Lý do lựa chọn: ", 
        "Cung cấp CSDL quan hệ đám mây chuẩn ACID, tự động sao lưu hàng ngày, tự động mở rộng dung lượng đĩa (Storage Auto-scaling), đóng vai trò là 'Trung tâm Đồng bộ' tiếp nhận các bản ghi UUID v4 và nhật ký delete_logs từ các thiết bị di động gửi lên."
    )

    add_sec_h2(doc, "3.6. Dịch Vụ Tính Toán Backend: Containerized AWS ECS Fargate")
    add_bullet_p(doc, "Lý do lựa chọn: ", 
        "Chạy API đồng bộ dưới dạng Docker Container hoàn toàn Serverless. Hệ thống tự động co giãn (Auto-scaling) từ 1 Container lên hàng chục Container trong các tuần thi cao điểm và tự động thu nhỏ lại khi ít sinh viên sử dụng, giúp tối ưu hóa chi phí."
    )

    add_sec_h2(doc, "3.7. Dịch Vụ Bảo Mật & Quản Lý Khóa: AWS KMS & IAM Roles")
    add_bullet_p(doc, "Lý do lựa chọn: ", 
        "Cung cấp khả năng mã hóa dữ liệu tĩnh chuẩn AES-256 (SSE-KMS) cho toàn bộ tệp trên S3. Bucket S3 được cấu hình Private tuyệt đối ('Block All Public Access'), chỉ cho phép truy cập qua Pre-signed URL có chữ ký số ngắn hạn."
    )

    # --------------------------------------------------------------------------
    # BƯỚC 4: THIẾT KẾ KIẾN TRÚC VÀ LUỒNG DỮ LIỆU
    # --------------------------------------------------------------------------
    add_sec_h1(doc, "4. THIẾT KẾ SƠ ĐỒ KIẾN TRÚC TÍCH HỢP CLOUD VÀ LUỒNG DỮ LIỆU TỐI ƯU CHO CASHEWDOC")

    add_sec_h2(doc, "4.1. Sơ đồ Kiến trúc So sánh Tổng quan: CashewDoc Hiện Tại vs. Tích Hợp Cloud")
    add_body_p(doc, 
        "Hình 4.1 so sánh trực quan sự chuyển dịch kiến trúc từ mô hình cục bộ một máy sang mô hình đám mây đàn hồi toàn cầu:"
    )

    if os.path.exists(arch_img):
        doc.add_paragraph()
        doc.add_picture(arch_img, width=Inches(6.4))
        add_caption(doc, "Hình 4.1: So sánh Kiến trúc CashewDoc Cục bộ Hiện tại (Trái) và Kiến trúc Tích hợp Cloud (Phải)")

    add_sec_h2(doc, "4.2. Sơ đồ Luồng Dữ liệu Chi tiết: Direct-to-S3 Upload qua Pre-signed URL")
    add_body_p(doc, 
        "Hình 4.2 mô tả chi tiết đường đi của luồng dữ liệu khi sinh viên thêm tài liệu kèm file đính kèm lớn và khi tải bài giảng về máy:"
    )

    if os.path.exists(flow_img):
        doc.add_paragraph()
        doc.add_picture(flow_img, width=Inches(6.4))
        add_caption(doc, "Hình 4.2: Luồng Dữ liệu Tải lên Trực tiếp qua Pre-signed URL và Tải xuống Tốc độ cao qua CDN CloudFront")

    add_sec_h2(doc, "4.3. Mô Tả Chi Tiết Quy Trình Tải Lên Tệp Bài Giảng (Direct Upload Workflow) 6 Bước")
    add_body_p(doc, "Khi sinh viên bấm 'Lưu tài liệu' kèm file Slide PDF (45MB) trên ứng dụng CashewDoc:")
    add_bullet_p(doc, "Bước 1 (Gửi Metadata nhẹ): ", "Ứng dụng Flutter gửi request JSON nhẹ chứa thông tin: Tiêu đề ('Bài giảng Kiến trúc Máy tính'), dung lượng (45MB), định dạng ('application/pdf') tới Backend API.")
    add_bullet_p(doc, "Bước 2 (Xác thực & Sinh Pre-signed URL): ", "Backend API xác thực JWT, sử dụng tiện ích UuidHelper để sinh chuỗi UUID v4 độc bản, gọi AWS S3 SDK tạo một Pre-signed PUT URL có thời hạn hiệu lực 5 phút và trả về cho ứng dụng di động.")
    add_bullet_p(doc, "Bước 3 (Upload trực tiếp lên Amazon S3): ", "Ứng dụng di động thực hiện lệnh HTTP PUT truyền luồng byte nhị phân 45MB thẳng lên Amazon S3 Bucket. File hoàn toàn KHÔNG đi qua Backend API, giải phóng 100% băng thông của server!")
    add_bullet_p(doc, "Bước 4 (Thông báo hoàn tất): ", "Khi S3 nhận file an toàn và trả về mã HTTP 200 OK kèm mã ETag, ứng dụng gửi thông báo xác nhận thành công về cho Backend API.")
    add_bullet_p(doc, "Bước 5 (Ghi CSDL Cloud): ", "Backend API ghi bản ghi metadata tài liệu (kèm đường dẫn S3 Key) vào Amazon RDS PostgreSQL.")
    add_bullet_p(doc, "Bước 6 (Cập nhật Local SQLite): ", "Ứng dụng CashewDoc ghi bản ghi vào CSDL SQLite cục bộ trên điện thoại và kích hoạt Reactive Stream để màn hình HomeScreen hiển thị tài liệu mới ngay tức khắc.")

    add_sec_h2(doc, "4.4. Quy Trình Tải Xuống & Xem Trước Tài Liệu (Preview via CDN)")
    add_bullet_p(doc, "Bước 1: ", "Sinh viên bấm vào tài liệu để xem trước file PDF. Ứng dụng gửi yêu cầu Document ID tới Backend API.")
    add_bullet_p(doc, "Bước 2: ", "Backend kiểm tra quyền truy cập của sinh viên và sinh một CloudFront Signed URL có thời hạn ngắn (15 phút).")
    add_bullet_p(doc, "Bước 3: ", "Ứng dụng di động tải file trực tiếp từ CloudFront Edge Server gần nhất với độ trễ siêu thấp (<50ms) và mở trực tiếp trên trình đọc PDF tích hợp của CashewDoc.")

    add_sec_h2(doc, "4.5. Thuật Toán Đồng Bộ 2 Chiều (Bidirectional Sync) Tận Dụng Sẵn Thiết Kế Của Bài Thực Hành")
    add_body_p(doc, 
        "Một ưu điểm vượt trội là mã nguồn Bài thực hành 1 đã được chuẩn bị sẵn 2 yếu tố then chốt để phục vụ đồng bộ đám mây:"
    )
    add_bullet_p(doc, "1. Khóa chính UUID v4: ", "Cho phép sinh viên thêm tài liệu trên điện thoại khi mất mạng mà không bao giờ bị trùng khóa chính với tài liệu thêm trên laptop khi kết nối lại mạng.")
    add_bullet_p(doc, "2. Bảng 'delete_logs': ", "Khi sinh viên xóa tài liệu trên điện thoại ở chế độ offline, bản ghi xóa được lưu vết vào bảng delete_logs. Khi có kết nối mạng, CloudSyncService chỉ cần gửi danh sách delete_logs lên server để xóa đồng bộ trên Cloud Database, giải quyết triệt để bài toán đồng bộ xóa đa thiết bị (Delete Propagation)!")

    # --------------------------------------------------------------------------
    # BƯỚC 5: ĐÁNH GIÁ TÁC ĐỘNG VỀ BẢO MẬT, CHI PHÍ VÀ HIỆU SUẤT
    # --------------------------------------------------------------------------
    add_sec_h1(doc, "5. ĐÁNH GIÁ TÁC ĐỘNG VỀ BẢO MẬT, CHI PHÍ VÀ HIỆU SUẤT SAU KHI TÍCH HỢP")

    add_sec_h2(doc, "5.1. Đánh giá Tác động về An toàn & Bảo mật (Security & Compliance)")
    add_bullet_p(doc, "Mã hóa toàn diện đa tầng: ", 
        "• Mã hóa luồng truyền (In-Transit): 100% kết nối qua giao thức HTTPS/TLS 1.3.\n"
        "• Mã hóa tĩnh (At-Rest): Toàn bộ tệp trên Amazon S3 được tự động mã hóa chuẩn AES-256 thông qua AWS KMS."
    )
    add_bullet_p(doc, "Kiểm soát truy cập cấp hạt mịn (Fine-grained Access Control): ", 
        "S3 Bucket hoàn toàn Private. Không ai có thể tải tệp nếu không có Pre-signed URL được cấp bởi Backend API kèm chữ ký HMAC-SHA256 và thời hạn hết hạn ngắn (5-15 phút)."
    )
    add_bullet_p(doc, "Kiểm toán lịch sử (Audit Trail): ", 
        "Dịch vụ AWS CloudTrail tự động ghi lại toàn bộ nhật ký truy cập (ai đọc/sửa/xóa tài liệu vào lúc nào), đáp ứng đầy đủ tiêu chuẩn bảo mật dữ liệu giáo dục."
    )

    add_sec_h2(doc, "5.2. Đánh giá Tác động về Chi phí Đầu tư & Vận hành (Cost Optimization cho Sinh viên)")
    add_bullet_p(doc, "Chuyển từ CapEx sang OpEx: ", 
        "Không cần mua sắm máy chủ hàng trăm triệu đồng ban đầu. Chi phí thanh toán theo mô hình Pay-as-you-go (Dùng bao nhiêu, trả bấy nhiêu)."
    )
    add_bullet_p(doc, "Bài toán chi phí thực tế cho quy mô sinh viên học viện PTIT: ", 
        "• Giả sử hệ thống phục vụ 1.000 sinh viên, lưu trữ 500 GB tài liệu học tập.\n"
        "• Chi phí lưu trữ S3 Standard: 500 GB * 0.023 USD/GB = 11.5 USD / tháng (~290.000 VNĐ / tháng).\n"
        "• Chi phí lưu trữ dài hạn với S3 Glacier Deep Archive (cho tài liệu các kỳ cũ): 500 GB * 0.00099 USD = 0.5 USD / tháng (~12.500 VNĐ / tháng)!\n"
        "• Nhờ Direct Upload, server Backend chỉ cần thuê gói ECS Fargate nhỏ (0.5 vCPU, 1GB RAM) tốn ~15 USD/tháng. Tổng chi phí toàn hệ thống chưa đến 30 USD/tháng (~750.000 VNĐ), tiết kiệm hơn 85% so với duy trì máy chủ riêng!"
    )

    add_sec_h2(doc, "5.3. Đánh giá Tác động về Hiệu suất & Độ sẵn sàng (Performance & High Availability)")
    add_bullet_p(doc, "Độ bền dữ liệu bất hoại: ", "99.999999999% (11 số 9), triệt tiêu hoàn toàn rủi ro mất tài liệu của sinh viên.")
    add_bullet_p(doc, "Khả năng chịu tải cực hạn trong mùa thi: ", "Amazon S3 hỗ trợ tối thiểu 3.500 requests PUT và 5.500 requests GET mỗi giây trên mỗi prefix. Hàng nghìn sinh viên có thể đồng thời nộp bài tập lớn mà không xảy ra hiện tượng nghẽn mạng hay sập hệ thống.")
    add_bullet_p(doc, "Tốc độ tải tài liệu vượt trội: ", "Nhờ CDN CloudFront, độ trễ tải bài giảng giảm từ hàng giây xuống dưới 50ms.")

    add_sec_h2(doc, "5.4. Bảng Tổng Hợp Đối Chiếu Trước và Sau Khi Chuyển Đổi Lên Cloud")

    eval_tbl = doc.add_table(rows=8, cols=4)
    eval_tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(eval_tbl, "CBD5E1")
    e_w = [Inches(1.4), Inches(1.8), Inches(2.0), Inches(1.8)]
    format_table_header(eval_tbl.rows[0], e_w, ["Tiêu Chí Đánh Giá", "Mô Hình Hiện Tại (CashewDoc Cục Bộ)", "Mô Hình Tích Hợp Cloud Đề Xuất", "Mức Độ Cải Thiện"])
    
    eval_data = [
        ("1. Phạm vi truy cập", "Bị cô lập trên 1 điện thoại di động của sinh viên", "Đa thiết bị: Điện thoại, Laptop, Máy tính bảng, Web", "Đột phá: Truy cập mọi lúc mọi nơi"),
        ("2. Độ an toàn dữ liệu", "Dễ mất trắng khi hỏng/mất máy hoặc gỡ cài đặt", "Độ bền 99.999999999%, sao lưu tự động đa vùng", "Tuyệt đối: Triệt tiêu rủi ro mất mát"),
        ("3. Dung lượng lưu trữ", "Giới hạn bởi bộ nhớ trong của điện thoại", "Mở rộng đàn hồi không giới hạn trên Amazon S3", "Giải phóng 100% bộ nhớ điện thoại"),
        ("4. Tải máy chủ Backend", "Nghẽn nặng nếu tải file qua server thông thường", "Giải phóng 100% nhờ Direct Upload qua Pre-signed URL", "Server chỉ xử lý JSON siêu nhẹ"),
        ("5. Tốc độ tải tệp", "Phụ thuộc kết nối mạng gia đình / nội bộ", "Siêu tốc (<50ms) nhờ mạng lưới CDN CloudFront", "Nhanh hơn 300% - 500%"),
        ("6. An toàn thông tin", "Lưu tệp thô trong bộ nhớ máy, không mã hóa", "Mã hóa AES-256 tĩnh (KMS), Pre-signed URL có TTL", "Chuẩn bảo mật doanh nghiệp quốc tế"),
        ("7. Khả năng chia sẻ", "Không hỗ trợ chia sẻ link cho bạn bè trong lớp", "Chia sẻ liên kết tài liệu bảo mật có thời hạn", "Tối ưu hóa học tập nhóm (Teamwork)"),
    ]
    for idx, r_vals in enumerate(eval_data):
        add_table_row(eval_tbl.rows[idx + 1], e_w, r_vals, is_even=(idx % 2 == 1))

    doc.add_paragraph()

    # --------------------------------------------------------------------------
    # KẾT LUẬN & ĐỀ XUẤT LỘ TRÌNH
    # --------------------------------------------------------------------------
    add_sec_h1(doc, "KẾT LUẬN & ĐỀ XUẤT LỘ TRÌNH TRIỂN KHAI CHO DỰ ÁN")
    
    add_body_p(doc, 
        "Việc phân tích và lập phương án tích hợp Điện toán Đám mây dựa trên chính ứng dụng Bài thực hành 1 (CashewDoc) đã chứng minh tính khả thi và giá trị thực tiễn to lớn:"
    )
    add_bullet_p(doc, "1. Kế thừa trọn vẹn nền tảng sẵn có: ", 
        "Dự án không cần phải đập đi xây lại mà tận dụng chính xác các thiết kế Clean Architecture, khóa chính UUID v4 và cơ chế ghi nhật ký delete_logs đã được xây dựng công phu trong Bài thực hành 1 để làm cầu nối đồng bộ lên Đám mây."
    )
    add_bullet_p(doc, "2. Đạt được trải nghiệm tốt nhất cho người học: ", 
        "Sinh viên vừa được tận hưởng tốc độ phản hồi 0ms của ứng dụng Offline-First khi ghi chép trên lớp học, vừa được bảo vệ an toàn dữ liệu trên Amazon S3 và có thể mở lại bài học trên máy tính ở nhà."
    )
    add_bullet_p(doc, "3. Lộ trình triển khai 3 giai đoạn kiến nghị: ", 
        "• Giai đoạn 1 (Lưu trữ tệp đám mây): Tích hợp AWS S3 SDK vào CashewDoc, thay đổi luồng lưu AttachmentModel từ file cục bộ sang Pre-signed URL trên S3.\n"
        "• Giai đoạn 2 (Đồng bộ Metadata): Triển khai API đồng bộ trên AWS ECS Fargate, kết nối SQLite cục bộ với Amazon RDS PostgreSQL.\n"
        "• Giai đoạn 3 (Tính năng thông minh): Tích hợp trí tuệ nhân tạo Amazon Textract để tự động trích xuất chữ viết tay và nội dung từ các ảnh chụp bảng bài giảng, nâng tầm CashewDoc thành hệ thống học tập thông minh toàn diện."
    )

    try:
        doc.save(DOCX_OUT)
        print(f"-> Tạo thành công tài liệu Word hoàn chỉnh: {DOCX_OUT}")
        return DOCX_OUT
    except PermissionError:
        backup_out = os.path.join(WORKSPACE_DIR, "phan_tich_va_lap_phuong_an_CashewDoc.docx")
        doc.save(backup_out)
        print(f"-> File {DOCX_OUT} đang mở trong WPS/Word. Đã lưu bản mới nhất vào: {backup_out}")
        return backup_out

if __name__ == "__main__":
    build_cloud_doc()
