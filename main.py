import sys

def main():
    try:
        print("Loyiha muvaffaqiyatli ishga tushdi!")
        # Bu yerga o'z logikangizni yozasiz
        # Masalan:
        result = 10 + 20
        print(f"Hisoblash natijasi: {result}")
        
    except Exception as e:
        print(f"Xatolik yuz berdi: {e}")
        sys.exit(1) # Xatolik bo'lsa exit code 1 qaytaradi

if __name__ == "__main__":
    main()
