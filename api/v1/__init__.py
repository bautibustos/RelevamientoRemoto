from fastapi import APIRouter

from api.v1 import areas, monitores, pc

router = APIRouter()
router.include_router(pc.router)
router.include_router(monitores.router)
router.include_router(areas.router)
