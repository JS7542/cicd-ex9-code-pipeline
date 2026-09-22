from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

app = FastAPI(title="Docker Web Lab")
templates = Jinja2Templates(directory="templates")


@app.get("/health")
def health():
    return {"status": "ok", "service": "fastapi"}


@app.get("/api/message")
def api_message():
    return {
        "message": "Nginx reverse proxy -> FastAPI communication success",
        "jinja2": True,
    }


@app.get("/kubernetes", response_class=HTMLResponse)
def kubernetes_page(request: Request):
    features = [
        {"name": "Pod", "desc": "컨테이너가 실행되는 Kubernetes의 최소 배포 단위"},
        {"name": "Deployment", "desc": "Pod의 복제본과 롤링 업데이트를 관리"},
        {"name": "Service", "desc": "Pod 집합에 안정적인 네트워크 엔드포인트 제공"},
        {"name": "ConfigMap / Secret", "desc": "애플리케이션 설정과 민감 정보를 분리"},
    ]
    return templates.TemplateResponse(
        request=request,
        name="kubernetes.html",
        context={"features": features, "title": "Kubernetes + Jinja2"},
    )
