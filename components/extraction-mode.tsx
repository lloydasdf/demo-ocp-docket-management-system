'use client';

import { useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Badge } from '@/components/ui/badge';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { extractFormData, getConfidenceStats, getMissingFields, getReviewFields, type ExtractionResult, type ExtractedField } from '@/lib/form-extraction';
import { Upload, AlertTriangle, CheckCircle2, AlertCircle, Download } from 'lucide-react';

interface ExtractionModeProps {
  onConfirmExtraction?: (data: ExtractionResult) => void;
}

export function ExtractionMode({ onConfirmExtraction }: ExtractionModeProps) {
  const [uploadedFile, setUploadedFile] = useState<File | null>(null);
  const [extraction, setExtraction] = useState<ExtractionResult | null>(null);
  const [editedFields, setEditedFields] = useState<Record<string, string | string[]>>({});
  const [reviewNotes, setReviewNotes] = useState('');
  const [activeTab, setActiveTab] = useState('extracted');

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setUploadedFile(file);
      setExtraction(null);
      setEditedFields({});
    }
  };

  const handleExtractData = () => {
    if (!uploadedFile) return;

    const result = extractFormData(uploadedFile.name, uploadedFile.type);
    setExtraction(result);

    // Initialize edited fields with extracted values
    const initialEdits: Record<string, string | string[]> = {};
    Object.entries(result.fields).forEach(([key, field]) => {
      initialEdits[key] = field.value;
    });
    setEditedFields(initialEdits);
  };

  const handleFieldChange = (fieldKey: string, value: string | string[]) => {
    setEditedFields({ ...editedFields, [fieldKey]: value });
  };

  const handleSaveDraft = () => {
    console.log('[v0] Saving draft with edited fields:', editedFields);
    alert('Draft saved to your account. You can continue editing later.');
  };

  const handleReviewMissing = () => {
    setActiveTab('missing');
  };

  const handleConfirmCreate = () => {
    if (onConfirmExtraction && extraction) {
      onConfirmExtraction(extraction);
    }
    alert('Docket entry created successfully!');
  };

  const stats = extraction ? getConfidenceStats(extraction.fields) : null;
  const missingFields = extraction ? getMissingFields(extraction.fields) : [];
  const reviewFields = extraction ? getReviewFields(extraction.fields) : [];

  return (
    <div className="space-y-6">
      {/* Upload Section */}
      <Card>
        <CardHeader>
          <CardTitle>Upload Investigation Form</CardTitle>
          <CardDescription>
            Upload scanned form, image, or PDF for automated data extraction
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="border-2 border-dashed border-border rounded-lg p-8 text-center hover:border-primary/50 transition-colors">
            <input
              type="file"
              accept=".pdf,.jpg,.jpeg,.png,.gif"
              onChange={handleFileUpload}
              className="hidden"
              id="file-upload"
            />
            <label htmlFor="file-upload" className="cursor-pointer">
              <div className="flex flex-col items-center gap-2">
                <Upload className="w-8 h-8 text-muted-foreground" />
                <p className="font-medium text-foreground">
                  {uploadedFile ? uploadedFile.name : 'Click to upload or drag and drop'}
                </p>
                <p className="text-xs text-muted-foreground">
                  PDF, JPG, PNG up to 25MB
                </p>
              </div>
            </label>
          </div>

          <div className="flex gap-2">
            <Button onClick={handleExtractData} disabled={!uploadedFile || !!extraction} className="flex-1">
              {extraction ? 'Data Extracted' : 'Extract Form Data'}
            </Button>
            {uploadedFile && (
              <Button
                variant="outline"
                onClick={() => {
                  setUploadedFile(null);
                  setExtraction(null);
                }}
              >
                Clear File
              </Button>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Extraction Results */}
      {extraction && (
        <>
          {/* Warning Alert */}
          <Alert className="border-orange-200 bg-orange-50">
            <AlertTriangle className="h-4 w-4 text-orange-600" />
            <AlertDescription className="text-orange-900 ml-2">
              <strong>Important:</strong> Extracted data must be reviewed by staff before saving. Review all fields for accuracy, especially those marked as "Needs Review" or "Missing".
            </AlertDescription>
          </Alert>

          {/* Extraction Stats */}
          <Card className="border-primary/20">
            <CardHeader className="pb-3">
              <div className="flex items-center justify-between">
                <div>
                  <CardTitle className="text-lg">Extraction Summary</CardTitle>
                  <CardDescription>Overall confidence: {stats?.overallConfidence}%</CardDescription>
                </div>
                <div className="flex gap-3">
                  <div className="text-center">
                    <p className="text-2xl font-bold text-green-600">{stats?.high}</p>
                    <p className="text-xs text-muted-foreground">High</p>
                  </div>
                  <div className="text-center">
                    <p className="text-2xl font-bold text-amber-600">{stats?.review}</p>
                    <p className="text-xs text-muted-foreground">Review</p>
                  </div>
                  <div className="text-center">
                    <p className="text-2xl font-bold text-red-600">{stats?.missing}</p>
                    <p className="text-xs text-muted-foreground">Missing</p>
                  </div>
                </div>
              </div>
            </CardHeader>
          </Card>

          {/* Tabs for Extraction Results */}
          <Tabs value={activeTab} onValueChange={setActiveTab}>
            <TabsList className="grid w-full grid-cols-4">
              <TabsTrigger value="extracted">Extracted Data</TabsTrigger>
              <TabsTrigger value="preview">Form Preview</TabsTrigger>
              <TabsTrigger value="missing">Missing Fields</TabsTrigger>
              <TabsTrigger value="duplicates">Duplicates</TabsTrigger>
            </TabsList>

            {/* Extracted Data Tab */}
            <TabsContent value="extracted" className="space-y-4">
              <Card>
                <CardHeader>
                  <CardTitle>Editable Extracted Fields</CardTitle>
                  <CardDescription>
                    Edit fields below. All changes are temporary until you confirm.
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  {Object.entries(extraction.fields).map(([key, field]) => (
                    <div key={key} className="space-y-2 pb-4 border-b border-border last:border-0">
                      <div className="flex items-center justify-between">
                        <Label htmlFor={key} className="font-medium text-foreground">
                          {field.name}
                        </Label>
                        <ConfidenceBadge confidence={field.confidence} />
                      </div>

                      {Array.isArray(editedFields[key]) ? (
                        <div className="space-y-2">
                          {(editedFields[key] as string[]).map((item, idx) => (
                            <Input
                              key={idx}
                              value={item}
                              onChange={(e) => {
                                const newArray = [...(editedFields[key] as string[])];
                                newArray[idx] = e.target.value;
                                handleFieldChange(key, newArray);
                              }}
                              placeholder={`${field.name} ${idx + 1}`}
                              className="text-sm"
                            />
                          ))}
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => {
                              const newArray = [...(editedFields[key] as string[]), ''];
                              handleFieldChange(key, newArray);
                            }}
                          >
                            Add {field.name}
                          </Button>
                        </div>
                      ) : (
                        <Input
                          id={key}
                          value={(editedFields[key] as string) || ''}
                          onChange={(e) => handleFieldChange(key, e.target.value)}
                          placeholder={`Enter ${field.name}`}
                          className="text-sm"
                        />
                      )}

                      {field.originalText && field.confidence !== 'high' && (
                        <p className="text-xs text-muted-foreground italic">
                          Original text: "{field.originalText}"
                        </p>
                      )}
                    </div>
                  ))}
                </CardContent>
              </Card>
            </TabsContent>

            {/* Form Preview Tab */}
            <TabsContent value="preview">
              <Card>
                <CardHeader>
                  <CardTitle>Uploaded Form Preview</CardTitle>
                  <CardDescription>This is a placeholder for the form preview</CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="aspect-video bg-muted rounded-lg border-2 border-dashed border-border flex items-center justify-center">
                    <div className="text-center">
                      <Upload className="w-12 h-12 text-muted-foreground mx-auto mb-2 opacity-50" />
                      <p className="text-sm text-muted-foreground">
                        {uploadedFile?.name}
                      </p>
                      <p className="text-xs text-muted-foreground mt-2">
                        Form preview would display here in production
                      </p>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </TabsContent>

            {/* Missing Fields Tab */}
            <TabsContent value="missing">
              <Card>
                <CardHeader>
                  <CardTitle>Missing Required Fields</CardTitle>
                  <CardDescription>
                    These fields could not be extracted. Please provide values manually.
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  {missingFields.length === 0 ? (
                    <div className="flex items-center gap-2 text-green-600">
                      <CheckCircle2 className="w-5 h-5" />
                      <p>All required fields have been extracted!</p>
                    </div>
                  ) : (
                    <div className="space-y-4">
                      {missingFields.map((field) => (
                        <div key={field.name} className="space-y-2 pb-4 border-b border-border last:border-0">
                          <Label className="font-medium text-foreground">{field.name}</Label>
                          <Input
                            value={(editedFields[Object.keys(extraction.fields).find(k => extraction.fields[k].name === field.name) || ''] as string) || ''}
                            onChange={(e) => {
                              const key = Object.keys(extraction.fields).find(k => extraction.fields[k].name === field.name);
                              if (key) handleFieldChange(key, e.target.value);
                            }}
                            placeholder={`Enter ${field.name}`}
                          />
                        </div>
                      ))}
                    </div>
                  )}
                </CardContent>
              </Card>
            </TabsContent>

            {/* Duplicates Tab */}
            <TabsContent value="duplicates">
              <div className="space-y-4">
                {/* Duplicate Persons */}
                <Card>
                  <CardHeader>
                    <CardTitle className="text-base">Possible Duplicate Persons</CardTitle>
                    <CardDescription>Similar names found in existing records</CardDescription>
                  </CardHeader>
                  <CardContent>
                    {extraction.duplicatePersonMatches.length === 0 ? (
                      <p className="text-sm text-muted-foreground">No similar persons found.</p>
                    ) : (
                      <div className="space-y-3">
                        {extraction.duplicatePersonMatches.map((match, idx) => (
                          <div key={idx} className="p-3 border border-border rounded-lg">
                            <div className="flex items-center justify-between">
                              <div>
                                <p className="font-medium text-sm">{match.name}</p>
                                <p className="text-xs text-muted-foreground">Docket: {match.docketId}</p>
                              </div>
                              <Badge variant="outline">
                                {Math.round(match.similarity * 100)}% match
                              </Badge>
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </CardContent>
                </Card>

                {/* Duplicate Dockets */}
                <Card>
                  <CardHeader>
                    <CardTitle className="text-base">Possible Duplicate Dockets</CardTitle>
                    <CardDescription>Similar dockets in the system</CardDescription>
                  </CardHeader>
                  <CardContent>
                    {extraction.potentialDuplicateDockets.length === 0 ? (
                      <p className="text-sm text-muted-foreground">No similar dockets found.</p>
                    ) : (
                      <div className="space-y-3">
                        {extraction.potentialDuplicateDockets.map((match, idx) => (
                          <div key={idx} className="p-3 border border-border rounded-lg">
                            <div className="flex items-center justify-between">
                              <div>
                                <p className="font-medium text-sm">{match.docketNumber}</p>
                              </div>
                              <Badge variant="secondary">
                                {Math.round(match.similarity * 100)}% similar
                              </Badge>
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </CardContent>
                </Card>
              </div>
            </TabsContent>
          </Tabs>

          {/* Review Notes */}
          <Card>
            <CardHeader>
              <CardTitle>Staff Review Notes</CardTitle>
              <CardDescription>Add notes about this extraction for the record</CardDescription>
            </CardHeader>
            <CardContent>
              <Textarea
                value={reviewNotes}
                onChange={(e) => setReviewNotes(e.target.value)}
                placeholder="e.g., Form quality was poor, manually verified respondent address, contacted complainant for clarification..."
                className="min-h-20"
              />
            </CardContent>
          </Card>

          {/* Action Buttons */}
          <div className="flex gap-2">
            <Button variant="outline" onClick={handleSaveDraft} className="flex-1">
              Save as Draft
            </Button>
            <Button variant="outline" onClick={handleReviewMissing} className="flex-1">
              <AlertCircle className="w-4 h-4 mr-2" />
              Review Missing Fields ({missingFields.length})
            </Button>
            <Button onClick={handleConfirmCreate} className="flex-1" disabled={missingFields.length > 0}>
              {missingFields.length > 0
                ? `Fill ${missingFields.length} Missing Fields`
                : 'Confirm and Create Docket Entry'}
            </Button>
          </div>
        </>
      )}
    </div>
  );
}

function ConfidenceBadge({ confidence }: { confidence: 'high' | 'review' | 'missing' }) {
  const variants = {
    high: { bg: 'bg-green-100', text: 'text-green-700', label: 'High Confidence' },
    review: { bg: 'bg-amber-100', text: 'text-amber-700', label: 'Needs Review' },
    missing: { bg: 'bg-red-100', text: 'text-red-700', label: 'Missing' },
  };

  const variant = variants[confidence];

  return (
    <Badge className={`${variant.bg} ${variant.text} border-0`}>
      {variant.label}
    </Badge>
  );
}
