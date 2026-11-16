<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue'
import type { PDFDocumentLoadingTask } from 'pdfjs-dist'
import pdfWorker from 'pdfjs-dist/build/pdf.worker.min.mjs?url'

type PdfJs = typeof import('pdfjs-dist')
let pdfjsPromise: Promise<PdfJs> | undefined

type ExportFormat = 'png' | 'jpeg'
type ConvertedImage = { name: string; url: string; size: number }

const fileInput = ref<HTMLInputElement | null>(null)
const file = ref<File | null>(null)
const pageCount = ref(0)
const format = ref<ExportFormat>('png')
const resolution = ref(1.5)
const isDragging = ref(false)
const isLoading = ref(false)
const isConverting = ref(false)
const progress = ref(0)
const errorMessage = ref('')
const images = ref<ConvertedImage[]>([])

function getPdfJs() {
  pdfjsPromise ??= import('pdfjs-dist').then((pdfjsLib) => {
    pdfjsLib.GlobalWorkerOptions.workerSrc = pdfWorker
    return pdfjsLib
  })
  return pdfjsPromise
}

const resolutionLabel = computed(() => `${resolution.value}×`)
const formatLabel = computed(() => format.value.toUpperCase())
const estimatedSize = computed(() => {
  if (!file.value) return '—'
  const size = file.value.size
  return size < 1024 * 1024 ? `${Math.max(1, Math.round(size / 1024))} KB` : `${(size / (1024 * 1024)).toFixed(1)} MB`
})

function clearImages() {
  images.value.forEach((image) => URL.revokeObjectURL(image.url))
  images.value = []
}

function openPicker() {
  fileInput.value?.click()
}

async function selectFile(selected?: File) {
  if (!selected || isLoading.value || isConverting.value) return
  if (!selected.name.toLowerCase().endsWith('.pdf') && selected.type !== 'application/pdf') {
    errorMessage.value = 'Este archivo no parece ser un PDF. Elige un archivo .pdf.'
    return
  }

  clearImages()
  errorMessage.value = ''
  file.value = selected
  pageCount.value = 0
  isLoading.value = true
  try {
    const pdfjsLib = await getPdfJs()
    const loadingTask = pdfjsLib.getDocument({ data: await selected.arrayBuffer() })
    const document = await loadingTask.promise
    pageCount.value = document.numPages
    await loadingTask.destroy()
  } catch {
    file.value = null
    errorMessage.value = 'No se pudo leer el PDF. Comprueba que el archivo no esté dañado o protegido.'
  } finally {
    isLoading.value = false
  }
}

function onFileChange(event: Event) {
  const input = event.target as HTMLInputElement
  void selectFile(input.files?.[0])
  input.value = ''
}

function onDrop(event: DragEvent) {
  isDragging.value = false
  void selectFile(event.dataTransfer?.files[0])
}

function removeFile() {
  if (isLoading.value || isConverting.value) return
  clearImages()
  file.value = null
  pageCount.value = 0
  progress.value = 0
  errorMessage.value = ''
}

function canvasToBlob(canvas: HTMLCanvasElement, mimeType: string, quality: number) {
  return new Promise<Blob>((resolve, reject) => {
    canvas.toBlob((blob) => {
      if (blob) resolve(blob)
      else reject(new Error('No se pudo crear la imagen.'))
    }, mimeType, quality)
  })
}

async function convertPdf() {
  if (!file.value || isConverting.value) return
  clearImages()
  errorMessage.value = ''
  progress.value = 0
  isConverting.value = true
  let loadingTask: PDFDocumentLoadingTask | undefined
  const convertedImages: ConvertedImage[] = []

  try {
    const pdfjsLib = await getPdfJs()
    loadingTask = pdfjsLib.getDocument({ data: await file.value.arrayBuffer() })
    const document = await loadingTask.promise
    const mimeType = format.value === 'png' ? 'image/png' : 'image/jpeg'
    const extension = format.value === 'png' ? 'png' : 'jpg'

    for (let pageNumber = 1; pageNumber <= document.numPages; pageNumber += 1) {
      const page = await document.getPage(pageNumber)
      const viewport = page.getViewport({ scale: resolution.value })
      const canvas = window.document.createElement('canvas')
      const context = canvas.getContext('2d')
      if (!context) throw new Error('El navegador no permite crear imágenes.')
      canvas.width = Math.ceil(viewport.width)
      canvas.height = Math.ceil(viewport.height)
      if (format.value === 'jpeg') {
        context.fillStyle = '#fff'
        context.fillRect(0, 0, canvas.width, canvas.height)
      }
      await page.render({ canvas, canvasContext: context, viewport }).promise
      const blob = await canvasToBlob(canvas, mimeType, 0.92)
      convertedImages.push({
        name: `${file.value.name.replace(/\.pdf$/i, '')}-pagina-${String(pageNumber).padStart(2, '0')}.${extension}`,
        url: URL.createObjectURL(blob),
        size: blob.size,
      })
      canvas.width = 0
      canvas.height = 0
      progress.value = Math.round((pageNumber / document.numPages) * 100)
    }
    images.value = convertedImages
  } catch (error) {
    convertedImages.forEach((image) => URL.revokeObjectURL(image.url))
    errorMessage.value = error instanceof Error ? error.message : 'La conversión ha fallado. Inténtalo con otro archivo.'
  } finally {
    await loadingTask?.destroy()
    isConverting.value = false
  }
}

function downloadImage(image: ConvertedImage) {
  const link = window.document.createElement('a')
  link.href = image.url
  link.download = image.name
  link.click()
}

function formatSize(bytes: number) {
  return bytes < 1024 * 1024 ? `${Math.max(1, Math.round(bytes / 1024))} KB` : `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}

onBeforeUnmount(clearImages)
</script>

<template>
  <div class="app-shell">
    <header class="topbar">
      <a class="brand" href="#" aria-label="PixelPDF, inicio">
        <span class="brand-mark" aria-hidden="true">
          <svg viewBox="0 0 32 32" fill="none"><path d="M8 3.75h10l7 7V27a1.25 1.25 0 0 1-1.25 1.25H8A1.25 1.25 0 0 1 6.75 27V5A1.25 1.25 0 0 1 8 3.75Z" stroke="currentColor" stroke-width="2"/><path d="M18 4v7h7M11 17h10M11 21h7" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M22.5 22.5v5m-2.5-2.5h5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>
        </span>
        <span>pixel<span class="brand-light">pdf</span></span>
      </a>
      <div class="topbar-right">
        <span class="privacy-note"><span class="privacy-dot"></span> Tus archivos son privados</span>
        <span class="topbar-divider"></span>
        <a class="help-link" href="#how-it-works">¿Cómo funciona?</a>
      </div>
    </header>

    <main>
      <section class="hero">
        <div class="eyebrow"><span class="eyebrow-icon">✳</span> CONVERTIDOR DE PDF GRATIS</div>
        <h1>Tus páginas PDF,<br /><span>en imágenes.</span></h1>
        <p class="hero-copy">Convierte cada página en una imagen de alta calidad.<br class="desktop-break" /> Fácil, rápido y totalmente privado.</p>
      </section>

      <section class="workspace" aria-label="Convertir un PDF">
        <div class="workspace-main">
          <div
            class="dropzone"
            :class="{ 'is-dragging': isDragging, 'has-file': file }"
            @dragenter.prevent="isDragging = true"
            @dragover.prevent="isDragging = true"
            @dragleave.prevent="isDragging = false"
            @drop.prevent="onDrop"
          >
            <input ref="fileInput" class="visually-hidden" type="file" accept=".pdf,application/pdf" @change="onFileChange" />
            <template v-if="!file">
              <div class="upload-icon">
                <svg viewBox="0 0 48 48" fill="none" aria-hidden="true"><path d="M15 35.5H12a8 8 0 0 1-.7-16A13 13 0 0 1 36.7 18 9 9 0 0 1 36 36h-3" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"/><path d="M24 33V20m0 0-5 5m5-5 5 5" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>
              </div>
              <h2>Arrastra tu PDF aquí</h2>
              <p>o <button class="text-button" type="button" @click="openPicker">busca el archivo</button></p>
              <div class="file-hint"><span class="pdf-badge">PDF</span> Solo archivos PDF <span class="hint-separator">·</span> Conversión local y segura</div>
            </template>
            <template v-else>
              <div class="file-card">
                <div class="pdf-file-icon"><svg viewBox="0 0 32 32" fill="none" aria-hidden="true"><path d="M8 3.75h10l7 7V27a1.25 1.25 0 0 1-1.25 1.25H8A1.25 1.25 0 0 1 6.75 27V5A1.25 1.25 0 0 1 8 3.75Z" stroke="currentColor" stroke-width="1.8"/><path d="M18 4v7h7M10 20h12" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/><text x="10" y="17" fill="currentColor" font-size="5" font-weight="800">PDF</text></svg></div>
                <div class="file-details">
                  <strong>{{ file.name }}</strong>
                  <span>{{ estimatedSize }} <template v-if="pageCount">· {{ pageCount }} {{ pageCount === 1 ? 'página' : 'páginas' }}</template><template v-else-if="isLoading">· Leyendo el documento…</template></span>
                </div>
                <button class="icon-button" type="button" aria-label="Quitar archivo" :disabled="isLoading || isConverting" @click="removeFile"><svg viewBox="0 0 20 20" fill="none"><path d="m5 5 10 10M15 5 5 15" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg></button>
              </div>
            </template>
          </div>

          <div v-if="errorMessage" class="error-message" role="alert">
            <svg viewBox="0 0 20 20" fill="none" aria-hidden="true"><circle cx="10" cy="10" r="8" stroke="currentColor" stroke-width="1.6"/><path d="M10 6v4m0 3h.01" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg>
            {{ errorMessage }}
          </div>

          <div v-if="isConverting" class="progress-panel" aria-live="polite">
            <div class="progress-copy"><span>Convirtiendo…</span><strong>{{ progress }}%</strong></div>
            <div class="progress-track"><div class="progress-fill" :style="{ width: `${progress}%` }"></div></div>
            <span class="progress-caption">Tus páginas se están convirtiendo en imágenes</span>
          </div>

          <button class="convert-button" type="button" :disabled="!file || isLoading || isConverting" @click="convertPdf">
            <template v-if="isConverting"><span class="spinner"></span> Convirtiendo…</template>
            <template v-else><svg viewBox="0 0 20 20" fill="none" aria-hidden="true"><path d="M10 3v14m0-14L5 8m5-5 5 5M4 13v3a1 1 0 0 0 1 1h10a1 1 0 0 0 1-1v-3" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg>{{ images.length ? 'Volver a convertir' : 'Convertir a imágenes' }}<span class="button-arrow">→</span></template>
          </button>
          <p class="button-caption"><svg viewBox="0 0 16 16" fill="none" aria-hidden="true"><path d="M8 1.75 13 4v3.5c0 3.2-2.14 5.55-5 6.75-2.86-1.2-5-3.55-5-6.75V4l5-2.25Z" stroke="currentColor" stroke-width="1.3"/><path d="m5.75 7.75 1.5 1.5 3-3" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/></svg> Gratis · Sin registro · Los archivos se procesan en tu dispositivo</p>
        </div>

        <aside class="settings-panel">
          <div class="panel-heading">
            <div>
              <span class="section-label">PERSONALIZACIÓN</span>
              <h2>Opciones de imagen</h2>
            </div>
            <span class="settings-sparkle">✳</span>
          </div>

          <div class="setting-group">
            <label class="setting-label" for="format">Formato de salida</label>
            <div id="format" class="format-switch" role="group" aria-label="Formato de salida">
              <button type="button" :class="{ active: format === 'png' }" :aria-pressed="format === 'png'" @click="format = 'png'">
                <span class="format-symbol png-symbol">P</span> PNG
              </button>
              <button type="button" :class="{ active: format === 'jpeg' }" :aria-pressed="format === 'jpeg'" @click="format = 'jpeg'">
                <span class="format-symbol jpg-symbol">J</span> JPG
              </button>
            </div>
            <p class="setting-help">{{ format === 'png' ? 'Sin pérdida de calidad, ideal para texto y gráficos.' : 'Archivos más ligeros, ideales para fotografías.' }}</p>
          </div>

          <div class="setting-group resolution-group">
            <div class="resolution-heading"><label class="setting-label" for="resolution">Resolución</label><span class="resolution-value">{{ resolutionLabel }}</span></div>
            <input id="resolution" v-model.number="resolution" type="range" min="1" max="3" step="0.5" :style="{ '--range-progress': `${((resolution - 1) / 2) * 100}%` }" />
            <div class="range-labels"><span>Estándar</span><span>Alta calidad</span></div>
          </div>

          <div class="settings-summary">
            <div class="summary-row"><span>Format</span><strong>{{ formatLabel }}</strong></div>
            <div class="summary-row"><span>Resolución</span><strong>{{ resolutionLabel }}</strong></div>
            <div class="summary-row"><span>Páginas por convertir</span><strong>{{ pageCount || '—' }}</strong></div>
          </div>
          <div class="privacy-card">
            <span class="lock-icon"><svg viewBox="0 0 20 20" fill="none" aria-hidden="true"><rect x="4" y="8.5" width="12" height="9" rx="2" stroke="currentColor" stroke-width="1.5"/><path d="M6.5 8.5V6a3.5 3.5 0 0 1 7 0v2.5m-3.5 3v2" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg></span>
            <span><strong>100 % privado</strong><small>Tus documentos nunca salen de tu dispositivo.</small></span>
          </div>
        </aside>
      </section>

      <section v-if="images.length" class="results-section" aria-live="polite">
        <div class="results-heading">
          <div><span class="section-label">CONVERSIÓN COMPLETADA</span><h2>{{ images.length }} {{ images.length === 1 ? 'imagen lista' : 'imágenes listas' }}</h2></div>
          <span class="success-pill"><span>✓</span> Listo</span>
        </div>
        <div class="image-grid">
          <article v-for="(image, index) in images" :key="image.url" class="image-card">
            <div class="image-preview"><img :src="image.url" :alt="`Vista previa de la página ${index + 1}`" /><span class="page-tag">PÁGINA {{ String(index + 1).padStart(2, '0') }}</span></div>
            <div class="image-info"><div><strong>{{ image.name }}</strong><span>{{ formatSize(image.size) }} · {{ formatLabel }}</span></div><button class="download-button" type="button" :aria-label="`Descargar ${image.name}`" @click="downloadImage(image)"><svg viewBox="0 0 20 20" fill="none" aria-hidden="true"><path d="M10 3v9m0 0 3.5-3.5M10 12 6.5 8.5M4 13v3a1 1 0 0 0 1 1h10a1 1 0 0 0 1-1v-3" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg></button></div>
          </article>
        </div>
      </section>

      <section id="how-it-works" class="how-section">
        <div class="how-heading"><span class="section-label">ASÍ DE FÁCIL</span><h2>Tres pasos y listo.</h2></div>
        <div class="steps-grid">
          <article class="step-card"><span class="step-number">01</span><div class="step-icon step-upload"><svg viewBox="0 0 24 24" fill="none"><path d="M12 16V4m0 0L7 9m5-5 5 5M5 14v4a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-4" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg></div><h3>Añade un PDF</h3><p>Arrastra el archivo a la zona o selecciónalo en tu dispositivo.</p></article>
          <article class="step-card"><span class="step-number">02</span><div class="step-icon step-tune"><svg viewBox="0 0 24 24" fill="none"><path d="M4 7h9m4 0h3M4 17h3m4 0h9M13 4v6M7 14v6" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/><circle cx="15" cy="7" r="2" stroke="currentColor" stroke-width="1.8"/><circle cx="9" cy="17" r="2" stroke="currentColor" stroke-width="1.8"/></svg></div><h3>Elige las opciones</h3><p>Selecciona el formato y la resolución que prefieras.</p></article>
          <article class="step-card"><span class="step-number">03</span><div class="step-icon step-download"><svg viewBox="0 0 24 24" fill="none"><path d="M12 4v12m0 0 5-5m-5 5-5-5M5 17v2a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-2" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg></div><h3>Descarga las imágenes</h3><p>Descarga cada página convertida y úsala donde quieras.</p></article>
        </div>
      </section>
    </main>

    <footer class="footer"><a class="footer-brand" href="#">pixelpdf</a><span>Tus documentos, tus reglas. Conversión local y segura.</span><span class="footer-right">Diseñado para ir al grano <span>✳</span></span></footer>
  </div>
</template>
