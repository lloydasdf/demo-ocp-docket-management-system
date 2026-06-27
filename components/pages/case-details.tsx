"use client";

import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Badge } from "@/components/ui/badge";
import { StatusBadge } from "@/components/status-badge";
import { getCaseById, getCaseWithAttachments, dockets } from "@/lib/dummy-data";
import { Button } from "@/components/ui/button";
import { Download, Mail } from "lucide-react";

interface CaseDetailsProps {
  caseId: string;
  docketId: string;
}

function formatPersonAddress(address: {
  type: string;
  street: string;
  barangay: string;
  municipality: string;
  province: string;
  zipCode: string;
  isPrimary: boolean;
}) {
  return [
    address.street,
    address.barangay ? `Brgy. ${address.barangay}` : null,
    address.municipality,
    address.province,
    address.zipCode,
  ]
    .filter(Boolean)
    .join(", ");
}

function PersonAddresses({
  addresses,
}: {
  addresses: Array<{
    id: string;
    type: string;
    street: string;
    barangay: string;
    municipality: string;
    province: string;
    zipCode: string;
    isPrimary: boolean;
  }>;
}) {
  if (addresses.length === 0) {
    return null;
  }

  return (
    <div className="mt-3 space-y-2 text-sm">
      <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
        Addresses
      </p>
      {addresses.map((address) => (
        <div key={address.id} className="rounded-md bg-muted/40 p-2">
          <div className="flex flex-wrap items-center gap-2">
            <span className="font-medium">{address.type}</span>
            {address.isPrimary ? (
              <Badge variant="secondary" className="text-xs">
                Primary
              </Badge>
            ) : null}
          </div>
          <p className="text-muted-foreground">
            {formatPersonAddress(address)}
          </p>
        </div>
      ))}
    </div>
  );
}

export default function CaseDetails({ caseId, docketId }: CaseDetailsProps) {
  const caseDetail = getCaseById(caseId);
  const caseWithAttachments = getCaseWithAttachments(caseId);
  const docket = dockets.find((d) => d.id === docketId);

  if (!caseDetail || !docket) {
    return (
      <div className="p-8">
        <Card>
          <CardContent className="pt-8">
            <p className="text-center text-muted-foreground">Case not found</p>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="p-8 space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-foreground">
            {caseDetail.caseNumber}
          </h1>
          <p className="text-muted-foreground mt-1">
            Docket: {docket.docketNumber}
          </p>
        </div>
        <StatusBadge status={caseDetail.status} size="lg" />
      </div>

      {/* Case Overview Card */}
      <Card>
        <CardHeader>
          <CardTitle>Case Overview</CardTitle>
        </CardHeader>
        <CardContent className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div>
            <p className="text-sm text-muted-foreground">Date of Incident</p>
            <p className="text-lg font-semibold">
              {new Date(caseDetail.dateOfIncident).toLocaleDateString()}
            </p>
          </div>
          <div>
            <p className="text-sm text-muted-foreground">Assigned Prosecutor</p>
            <p className="text-lg font-semibold">
              {caseDetail.prosecutor || "Unassigned"}
            </p>
          </div>
          <div>
            <p className="text-sm text-muted-foreground">Violations</p>
            <p className="text-lg font-semibold">
              {caseDetail.violations.length}
            </p>
          </div>
        </CardContent>
      </Card>

      {/* Tabs */}
      <Tabs defaultValue="overview" className="w-full">
        <TabsList className="grid w-full grid-cols-6">
          <TabsTrigger value="overview">Overview</TabsTrigger>
          <TabsTrigger value="parties">Parties</TabsTrigger>
          <TabsTrigger value="cases">Cases</TabsTrigger>
          <TabsTrigger value="violations">Violations</TabsTrigger>
          <TabsTrigger value="history">History</TabsTrigger>
          <TabsTrigger value="attachments">Attachments</TabsTrigger>
        </TabsList>

        {/* Overview Tab */}
        <TabsContent value="overview">
          <Card>
            <CardHeader>
              <CardTitle>Case Information</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <h4 className="font-semibold mb-3">Key Details</h4>
                  <div className="space-y-2 text-sm">
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">
                        Case Number:
                      </span>
                      <span className="font-medium">
                        {caseDetail.caseNumber}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Status:</span>
                      <StatusBadge status={caseDetail.status} size="sm" />
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">
                        Date of Incident:
                      </span>
                      <span className="font-medium">
                        {new Date(
                          caseDetail.dateOfIncident,
                        ).toLocaleDateString()}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Prosecutor:</span>
                      <span className="font-medium">
                        {caseDetail.prosecutor || "—"}
                      </span>
                    </div>
                  </div>
                </div>
                <div>
                  <h4 className="font-semibold mb-3">Parties Involved</h4>
                  <div className="space-y-2 text-sm">
                    <div>
                      <span className="text-muted-foreground">
                        Complainants:
                      </span>
                      <span className="ml-2 font-medium">
                        {caseDetail.complainants.length}
                      </span>
                    </div>
                    <div>
                      <span className="text-muted-foreground">
                        Respondents:
                      </span>
                      <span className="ml-2 font-medium">
                        {caseDetail.respondents.length}
                      </span>
                    </div>
                    <div>
                      <span className="text-muted-foreground">Witnesses:</span>
                      <span className="ml-2 font-medium">
                        {caseDetail.witnesses.length}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Parties Tab */}
        <TabsContent value="parties" className="space-y-4">
          {/* Complainants */}
          <Card>
            <CardHeader>
              <CardTitle>Complainants</CardTitle>
            </CardHeader>
            <CardContent>
              {caseDetail.complainants.length === 0 ? (
                <p className="text-muted-foreground">
                  No complainants recorded
                </p>
              ) : (
                <div className="space-y-3">
                  {caseDetail.complainants.map((person) => (
                    <div
                      key={person.id}
                      className="p-3 border border-border rounded"
                    >
                      <p className="font-semibold">
                        {person.firstName} {person.middleName} {person.lastName}
                      </p>
                      <p className="text-sm text-muted-foreground">
                        {person.contactNumber} | {person.email}
                      </p>
                      <PersonAddresses addresses={person.addresses} />
                      {person.aliases.length > 0 && (
                        <div className="mt-2 flex flex-wrap gap-2">
                          {person.aliases.map((alias) => (
                            <Badge
                              key={alias}
                              variant="secondary"
                              className="text-xs"
                            >
                              {alias}
                            </Badge>
                          ))}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>

          {/* Respondents */}
          <Card>
            <CardHeader>
              <CardTitle>Respondents</CardTitle>
            </CardHeader>
            <CardContent>
              {caseDetail.respondents.length === 0 ? (
                <p className="text-muted-foreground">No respondents recorded</p>
              ) : (
                <div className="space-y-3">
                  {caseDetail.respondents.map((person) => (
                    <div
                      key={person.id}
                      className="p-3 border border-border rounded"
                    >
                      <p className="font-semibold">
                        {person.firstName} {person.middleName} {person.lastName}
                      </p>
                      <p className="text-sm text-muted-foreground">
                        {person.contactNumber} | {person.email}
                      </p>
                      <PersonAddresses addresses={person.addresses} />
                      {person.aliases.length > 0 && (
                        <div className="mt-2 flex flex-wrap gap-2">
                          {person.aliases.map((alias) => (
                            <Badge
                              key={alias}
                              variant="secondary"
                              className="text-xs"
                            >
                              {alias}
                            </Badge>
                          ))}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>

          {/* Witnesses */}
          <Card>
            <CardHeader>
              <CardTitle>Witnesses</CardTitle>
            </CardHeader>
            <CardContent>
              {caseDetail.witnesses.length === 0 ? (
                <p className="text-muted-foreground">No witnesses recorded</p>
              ) : (
                <div className="space-y-3">
                  {caseDetail.witnesses.map((person) => (
                    <div
                      key={person.id}
                      className="p-3 border border-border rounded"
                    >
                      <p className="font-semibold">
                        {person.firstName} {person.middleName} {person.lastName}
                      </p>
                      <p className="text-sm text-muted-foreground">
                        {person.contactNumber} | {person.email}
                      </p>
                      <PersonAddresses addresses={person.addresses} />
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* Cases Tab */}
        <TabsContent value="cases">
          <Card>
            <CardHeader>
              <CardTitle>Case Information</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Docket Number:</span>
                  <span className="font-medium">{docket.docketNumber}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Case Number:</span>
                  <span className="font-medium">{caseDetail.caseNumber}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Date Created:</span>
                  <span className="font-medium">
                    {new Date(docket.createdDate).toLocaleDateString()}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Current Status:</span>
                  <StatusBadge status={caseDetail.status} size="sm" />
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Violations Tab */}
        <TabsContent value="violations">
          <Card>
            <CardHeader>
              <CardTitle>Alleged Violations</CardTitle>
            </CardHeader>
            <CardContent>
              {caseDetail.violations.length === 0 ? (
                <p className="text-muted-foreground">No violations recorded</p>
              ) : (
                <div className="space-y-4">
                  {caseDetail.violations.map((violation) => (
                    <div
                      key={violation.id}
                      className="p-4 border border-border rounded-lg"
                    >
                      <div className="flex items-start justify-between mb-2">
                        <h4 className="font-semibold">
                          {violation.description}
                        </h4>
                        <Badge className="bg-primary">
                          {violation.statute}
                        </Badge>
                      </div>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
                        <div>
                          <span className="text-muted-foreground">
                            Date Committed:
                          </span>
                          <p className="font-medium">
                            {violation.dateCommitted
                              ? new Date(
                                  violation.dateCommitted,
                                ).toLocaleDateString()
                              : "—"}
                          </p>
                        </div>
                        <div>
                          <span className="text-muted-foreground">
                            Location:
                          </span>
                          <p className="font-medium">
                            {violation.location || "—"}
                          </p>
                        </div>
                      </div>
                      {violation.details && (
                        <div className="mt-3 pt-3 border-t border-border">
                          <p className="text-sm text-muted-foreground mb-1">
                            Details:
                          </p>
                          <p className="text-sm">{violation.details}</p>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* Status History Tab */}
        <TabsContent value="history">
          <Card>
            <CardHeader>
              <CardTitle>Status History</CardTitle>
            </CardHeader>
            <CardContent>
              {caseDetail.statusHistory.length === 0 ? (
                <p className="text-muted-foreground">
                  No status history recorded
                </p>
              ) : (
                <div className="space-y-4">
                  {caseDetail.statusHistory.map((update, index) => (
                    <div key={update.id} className="flex gap-4">
                      <div className="flex flex-col items-center">
                        <div className="w-4 h-4 rounded-full bg-primary"></div>
                        {index < caseDetail.statusHistory.length - 1 && (
                          <div className="w-1 h-12 bg-border mt-1"></div>
                        )}
                      </div>
                      <div className="pb-4">
                        <div className="flex items-center gap-2 mb-1">
                          <p className="font-semibold">{update.status}</p>
                          <p className="text-xs text-muted-foreground">
                            {new Date(update.date).toLocaleDateString()}
                          </p>
                        </div>
                        <p className="text-sm text-muted-foreground mb-1">
                          {update.remarks}
                        </p>
                        <p className="text-xs text-muted-foreground">
                          By: {update.updatedBy}
                        </p>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* Attachments Tab */}
        <TabsContent value="attachments">
          <Card>
            <CardHeader>
              <CardTitle>Attachments</CardTitle>
            </CardHeader>
            <CardContent>
              {!caseWithAttachments ||
              caseWithAttachments.attachments.length === 0 ? (
                <p className="text-muted-foreground">No attachments</p>
              ) : (
                <div className="space-y-2">
                  {caseWithAttachments.attachments.map((attachment) => (
                    <div
                      key={attachment.id}
                      className="flex items-center justify-between p-3 border border-border rounded-lg hover:bg-muted/50"
                    >
                      <div className="flex-1 min-w-0">
                        <p className="font-medium truncate">
                          {attachment.fileName}
                        </p>
                        <p className="text-xs text-muted-foreground">
                          {attachment.size} • Uploaded{" "}
                          {new Date(attachment.uploadDate).toLocaleDateString()}{" "}
                          by {attachment.uploadedBy}
                        </p>
                      </div>
                      <Button variant="ghost" size="sm">
                        <Download className="w-4 h-4" />
                      </Button>
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}
