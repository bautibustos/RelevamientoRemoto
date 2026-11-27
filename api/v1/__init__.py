from fastapi import APIRouter

from api.v1 import areas, interfaces, monitores, pc, sistema

router = APIRouter()
router.include_router(pc.router)
router.include_router(monitores.router)
router.include_router(areas.router)
router.include_router(interfaces.router)
router.include_router(sistema.router)
